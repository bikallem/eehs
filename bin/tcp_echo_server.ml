open Eehs

let pp_sockaddr fmt = function
  | Unix.ADDR_UNIX _ -> failwith "Unix domain socket not supported"
  | ADDR_INET (addr, port) ->
    Format.fprintf fmt "%s.%d" (Unix.string_of_inet_addr addr) port

let clientfd_cb (epoll : Epoll.t) (_ : Unix.sockaddr)
    (client_fd, (_ : Epoll.Io_events.t)) =
  let buflen = 1024 in
  let buf = Bytes.create buflen in
  match Epoll.read client_fd buf 0 buflen with
  | got when got = 0 ->
    Epoll.remove epoll client_fd;
    Unix.close client_fd
  | got -> ignore (Unix.write client_fd buf 0 got : int)
  | exception Unix.Unix_error ((EAGAIN | EWOULDBLOCK), _, _) -> ()

let serverfd_cb (epoll : Epoll.t) fdcb (server_fd, (_ : Epoll.Io_events.t)) =
  let client_fd, client_addr = Epoll.accept4 ~cloexec:true server_fd in

  Format.(fprintf std_formatter "\nConnected to %a%!" pp_sockaddr client_addr);

  Epoll.add epoll client_fd Epoll.Io_events.read;
  let clientfd_cb = clientfd_cb epoll client_addr in
  Hashtbl.replace fdcb client_fd clientfd_cb

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
  Epoll.add epoll server_fd Epoll.Io_events.read;

  (* hashtble with mapping {file_descr => callback} *)
  let fdcb = Hashtbl.create max_connections in
  Hashtbl.replace fdcb server_fd (serverfd_cb epoll fdcb);

  (* Run epoll/accept loop *)
  while true do
    Epoll.epoll_wait ~timeout_ms:(-1) epoll;
    Epoll.iter epoll (fun fd io_events ->
        let cb = Hashtbl.find fdcb fd in
        cb (fd, io_events))
  done
