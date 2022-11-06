let run _f = ()

let () =
  let addr = Unix.(ADDR_INET (inet6_addr_loopback, 9000)) in
  let server_fd = Unix.(socket ~cloexec:true PF_INET SOCK_STREAM 0) in
  Unix.set_nonblock server_fd;
  Unix.bind server_fd addr;
  Unix.listen server_fd 1024;
  run Fun.id
