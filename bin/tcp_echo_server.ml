open Eehs

let pp_sockaddr fmt = function
  | Unix.ADDR_UNIX _ -> failwith "Unix domain socket not supported"
  | ADDR_INET (addr, port) ->
    Format.fprintf fmt "%s.%d" (Unix.string_of_inet_addr addr) port

let handle_client client_fd _client_addr () =
  let buflen = 1024 in
  let buf = Bytes.create buflen in
  match Unix.read client_fd buf 0 buflen with
  | got when got = 0 -> () (* TODO close and remove from epoll. *)
  | got -> ignore (Unix.write client_fd buf 0 got : int)
  | exception Unix.Unix_error ((EAGAIN | EWOULDBLOCK), _, _) -> ()

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
  Epoll.add epoll server_fd Epoll.Io_events.readable;

  let client_connections = Hashtbl.create max_connections in

  (* Run epoll/accept loop *)
  while true do
    Epoll.epoll_wait ~timeout_ms:(-1) epoll;
    Epoll.iter epoll (fun fd _io_events ->
        if fd = server_fd then (
          let client_fd, client_addr = Unix.accept ~cloexec:true server_fd in
          Format.(
            fprintf std_formatter "\nConnected to %a%!" pp_sockaddr client_addr);

          Unix.set_nonblock client_fd;
          Epoll.add epoll client_fd Epoll.Io_events.readable;
          let handle_client = handle_client client_fd client_addr in
          Hashtbl.replace client_connections client_fd handle_client)
        else
          let handle_client = Hashtbl.find client_connections fd in
          handle_client ())
  done
