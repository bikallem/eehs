module C = Configurator.V1

let () =
  let import c =
    C.C_define.import c ~c_flags:["-D_GNU_SOURCE"]
      ~includes:["sys/epoll.h"; "stddef.h"]
  in
  C.main ~name:"configure" (fun c ->
      let defs =
        import c
          C.C_define.Type.
            [ ("EPOLL_CTL_ADD", Int)
            ; ("EPOLL_CTL_MOD", Int)
            ; ("EPOLL_CTL_DEL", Int)
            ; (* Events flags for epoll_wait(). https://man7.org/linux/man-pages/man2/epoll_ctl.2.html *)
              ("EPOLLIN", Int)
            ; ("EPOLLOUT", Int)
            ; ("EPOLLRDHUP", Int)
            ; ("EPOLLPRI", Int)
            ; ("EPOLLERR", Int)
            ; ("EPOLLHUP", Int)
            ; ("EPOLLET", Int)
            ; ("EPOLLONESHOT", Int)
            ; ("EPOLLWAKEUP", Int)
            ; ("EPOLLEXCLUSIVE", Int) ]
        |> List.map (function
             | name, C.C_define.Value.Int v ->
                 Printf.sprintf "let %s = 0x%x" (String.lowercase_ascii name) v
             | _ ->
                 assert false )
      in
      let sizeofs =
        import c
          C.C_define.Type.
            [ ("offsetof(struct epoll_event, data.fd)", Int)
            ; ("offsetof(struct epoll_event, events)", Int)
            ; ("sizeof(struct epoll_event)", Int) ]
        |> List.map (function
             | name, C.C_define.Value.Int v ->
                 let name =
                   match name with
                   | "offsetof(struct epoll_event, data.fd)" ->
                       "offsetof_epoll_fd"
                   | "offsetof(struct epoll_event, events)" ->
                       "offsetof_epoll_events"
                   | "sizeof(struct epoll_event)" ->
                       "sizeof_epoll_event"
                   | _ ->
                       assert false
                 in
                 Printf.sprintf "let %s = 0x%x" (String.lowercase_ascii name) v
             | _ ->
                 assert false )
      in
      let lines = defs @ sizeofs in
      C.Flags.write_lines "config.ml" lines )
