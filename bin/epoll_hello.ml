open Eehs

let () = 
  let _epoll = Epoll.epoll_create1 false in  
  print_endline "Hello, World!"
