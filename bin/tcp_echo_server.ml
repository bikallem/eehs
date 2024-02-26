open Eehs

type client = {
  read_buf : Bytes.t; (* read buffer *)
  epoll : Epoll.t;
  addr : Unix.sockaddr; (* client address *)
  fd : Unix.file_descr; (* client file descripter for read/write *)
  mutable fd_closed : bool;
  mutable read_offset : int;
      (* count of bytes in read_buf available. set by read syscall *)
}

type callback = Epoll.Io_events.t -> unit

let initial_buffer_size = 0x1000 (* 4K *)

let pp_sockaddr fmt = function
  | Unix.ADDR_UNIX _ -> failwith "Unix domain socket not supported"
  | ADDR_INET (addr, port) ->
    Format.fprintf fmt "%s:%i" (Unix.string_of_inet_addr addr) port

let traceln fmt = Format.(fprintf std_formatter ("\n+" ^^ fmt ^^ "%!"))

let client_cb (client : client) (ev : Epoll.Io_events.t) =
  let readable = Epoll.Io_events.readable ev in
  let writable = Epoll.Io_events.writable ev in
  let len = Bytes.length client.read_buf - client.read_offset in
  traceln
    "client_cb: readable: %b, writable: %b, fd_closed: %b, len: %d, ev: %o"
    readable writable client.fd_closed len
    (ev :> int);

  if readable && (not client.fd_closed) && len > 0 then (
    traceln "reading ..";
    match Epoll.read client.fd client.read_buf client.read_offset len with
    | got when got = 0 ->
      Epoll.remove client.epoll client.fd;
      Unix.close client.fd;
      client.fd_closed <- true
    | got when got > 0 ->
      let rcvdbytes = Bytes.sub client.read_buf client.read_offset got in
      client.read_offset <- client.read_offset + got;
      traceln "\ngot: %d bytes, %S" got (Bytes.unsafe_to_string rcvdbytes)
    | _ -> Error.raise_syscall_error "read");

  if (not client.fd_closed) && client.read_offset > 0 then (
    traceln "writing ...";
    (* TODO check for EGAIN/EWOULDBLOCK *)
    let wrote = Unix.write client.fd client.read_buf 0 client.read_offset in
    client.read_offset <- client.read_offset - wrote;
    traceln "\nwrote: %d bytes" wrote)

let server_cb (epoll : Epoll.t) (fdcb : (Unix.file_descr, callback) Hashtbl.t)
    server_fd (_ : Epoll.Io_events.t) =
  let rec accept_loop () =
    let ret, addr = Epoll.accept4 server_fd in
    if ret = -1 then begin
      let errno = Error.caml_errno () in
      if errno = Err_config.eagain || errno = Err_config.ewouldblock then ()
      else Error.raise_syscall_error "accept4"
    end
    else
      let addr = Option.get addr in
      let fd = Epoll.file_descr_of_int ret in
      let client =
        {
          read_buf = Bytes.create initial_buffer_size (* 4K *);
          epoll;
          addr;
          fd;
          fd_closed = false;
          read_offset = 0;
        }
      in
      traceln "Connected to %a" pp_sockaddr client.addr;
      Epoll.add epoll client.fd Epoll.Io_events.read;
      let client_cb = client_cb client in
      Hashtbl.replace fdcb client.fd client_cb;
      accept_loop ()
  in
  accept_loop ()

let max_connections = 128

let () =
  (* Setup server socket. *)
  let addr = Unix.(ADDR_INET (inet_addr_loopback, 9000)) in
  let server_fd = Unix.(socket ~cloexec:true PF_INET SOCK_STREAM 0) in
  Unix.set_nonblock server_fd;
  Unix.(setsockopt server_fd SO_REUSEADDR true);
  Unix.(setsockopt server_fd SO_REUSEPORT true);
  Unix.bind server_fd addr;
  Unix.listen server_fd max_connections;

  let epoll = Epoll.create max_connections in
  Epoll.add epoll server_fd Epoll.Io_events.rw;

  (* hashtble with mapping {file_descr => callback}
     TODO remove hashtable usage by storing cb directly into epoll
  *)
  let fdcb = Hashtbl.create max_connections in
  let server_cb = server_cb epoll fdcb server_fd in
  Hashtbl.replace fdcb server_fd server_cb;

  (* Run epoll/accept loop *)
  while true do
    Epoll.epoll_wait ~timeout_ms:1000 epoll;
    Epoll.iter epoll (fun fd io_events ->
        let cb = Hashtbl.find fdcb fd in
        cb io_events)
  done
