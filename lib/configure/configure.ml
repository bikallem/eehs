module C = Configurator.V1

let () =
  C.main ~name:"configure" (fun c ->
    C.C_define.import c 
      ~c_flags:["-D_GNU_SOURCE"] 
      ~includes:["sys/epoll.h"]
      C.C_define.Type.[
        "EPOLL_CTL_ADD", Int;
        "EPOLL_CTL_MOD", Int;
        "EPOLL_CTL_DEL", Int;

        (* Events flags for epoll_wait(). https://man7.org/linux/man-pages/man2/epoll_ctl.2.html *)
        "EPOLLIN", Int;
        "EPOLLOUT", Int;
        "EPOLLRDHUP", Int;
        "EPOLLPRI", Int;
        "EPOLLERR", Int;
        "EPOLLHUP", Int;
        "EPOLLET", Int;
        "EPOLLONESHOT", Int;
        "EPOLLWAKEUP", Int;
        "EPOLLEXCLUSIVE", Int;
      ]
    |> List.map (function 
      | name, C.C_define.Value.Int v -> Printf.sprintf "let %s = Optint.Int63.of_int 0x%x" (String.lowercase_ascii name) v
      | _ -> assert false)
    |> C.Flags.write_lines "config.ml"
  )
