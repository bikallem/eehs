open Eehs

let () =
  let _epoll = Epoll.create 10 in
  print_endline "Hello, World!"
