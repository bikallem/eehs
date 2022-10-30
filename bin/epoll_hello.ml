open Eehs

let () =
  let _epoll = Epoll.epoll_create () in
  print_endline "Hello, World!"
