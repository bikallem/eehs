open Eehs

let handle_client io_events _client_fd _client_addr =
  let buf = Bytes.create 1024 in
  if Epoll.Io_events.is_readable io_events then ()
  else if Epoll.Io_events.is_writable io_events then ()
  else ()

let client_connections = Hashtbl.create 10

let rec run epoll server_fd =
  Epoll.poll_io epoll;
  Epoll.iter epoll (fun fd io_events ->
      if fd = server_fd then (
        let client_fd, client_addr = Unix.accept ~cloexec:true server_fd in
        Epoll.add epoll client_fd Epoll.Io_events.rw;
        Hashtbl.add client_connections client_fd client_addr)
      else
        match Hashtbl.find client_connections fd with
        | client_addr -> handle_client io_events fd client_addr
        | exception Not_found -> assert false);
  run epoll server_fd

let () =
  let addr = Unix.(ADDR_INET (inet6_addr_loopback, 9000)) in
  let server_fd = Unix.(socket ~cloexec:true PF_INET SOCK_STREAM 0) in
  Unix.setsockopt server_fd Unix.SO_REUSEADDR true;
  Unix.bind server_fd addr;
  Unix.listen server_fd 128;

  let epoll = Epoll.create 128 in
  Epoll.add epoll server_fd Epoll.Io_events.readable;
  run epoll server_fd
