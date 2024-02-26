module C = Configurator.V1

let c_flags = [ "-D_GNU_SOURCE" ]

let gen_socket_config c =
  let open C.C_define in
  let defs =
    C.C_define.import c ~c_flags
      ~includes:[ "stddef.h"; "sys/socket.h"; "netinet/in.h" ]
      [
        ("AF_INET", Type.Int);
        ("AF_INET6", Type.Int);
        ("AF_UNIX", Type.Int);
        ("SOCK_NONBLOCK", Type.Int);
        ("SOCK_CLOEXEC", Type.Int);
        ("sizeof(socklen_t)", Type.Int);
        ("sizeof(struct sockaddr_storage)", Type.Int);
        ("sizeof(struct in_addr)", Type.Int);
        ("sizeof(struct in6_addr)", Type.Int);
        ("offsetof(struct sockaddr_storage, ss_family)", Type.Int);
        ("offsetof(struct sockaddr_in, sin_port)", Type.Int);
        ("offsetof(struct sockaddr_in, sin_addr)", Type.Int);
        ("offsetof(struct sockaddr_in6, sin6_port)", Type.Int);
        ("offsetof(struct sockaddr_in6, sin6_addr)", Type.Int);
      ]
  in
  let map_to_ml (name, v) =
    let name =
      match name with
      | "sizeof(socklen_t)" -> "socklen_t_sz"
      | "sizeof(struct sockaddr_storage)" -> "sockaddr_storage_sz"
      | "sizeof(struct in_addr)" -> "in_addr_sz"
      | "sizeof(struct in6_addr)" -> "in6_addr_sz"
      | "offsetof(struct sockaddr_storage, ss_family)" -> "sa_ss_family_ofs"
      | "offsetof(struct sockaddr_in, sin_port)" -> "sin_port_ofs"
      | "offsetof(struct sockaddr_in, sin_addr)" -> "sin_addr_ofs"
      | "offsetof(struct sockaddr_in6, sin6_port)" -> "sin6_port_ofs"
      | "offsetof(struct sockaddr_in6, sin6_addr)" -> "sin6_addr_ofs"
      | name -> String.lowercase_ascii name
    in
    let v = match v with Value.Int i -> string_of_int i | _ -> assert false in
    String.concat " " [ "let"; name; "="; v ]
  in
  let ml_defs = List.map map_to_ml defs in
  C.Flags.write_lines "sock_cfg.ml" ml_defs

let gen_error_config c =
  let open C.C_define in
  let defs =
    C.C_define.import c ~c_flags ~includes:[ "errno.h" ]
      [ ("EAGAIN", Int); ("EWOULDBLOCK", Int) ]
  in
  let map_to_ml = function
    | name, Value.Int v ->
      String.concat " "
        [ "let"; String.lowercase_ascii name; "="; string_of_int v ]
    | _ -> assert false
  in
  let ml_defs = List.map map_to_ml defs in
  C.Flags.write_lines "err_cfg.ml" ml_defs

let gen_epoll_config c =
  let open C.C_define in
  let defs =
    (* Events flags for epoll_wait(). https://man7.org/linux/man-pages/man2/epoll_ctl.2.html *)
    C.C_define.import c ~c_flags
      ~includes:[ "sys/epoll.h"; "stddef.h" ]
      [
        ("EPOLL_CTL_ADD", Type.Int);
        ("EPOLL_CTL_MOD", Int);
        ("EPOLL_CTL_DEL", Int);
        ("EPOLLIN", Int);
        ("EPOLLOUT", Int);
        ("EPOLLRDHUP", Int);
        ("EPOLLPRI", Int);
        ("EPOLLERR", Int);
        ("EPOLLHUP", Int);
        ("EPOLLET", Int);
        ("EPOLLONESHOT", Int);
        ("EPOLLWAKEUP", Int);
        ("EPOLLEXCLUSIVE", Int);
        ("offsetof(struct epoll_event, data.fd)", Int);
        ("offsetof(struct epoll_event, events)", Int);
        ("sizeof(struct epoll_event)", Int);
      ]
  in
  let map_to_ml (name, v) =
    let name =
      match name with
      | "offsetof(struct epoll_event, data.fd)" -> "epoll_event_data_fd"
      | "offsetof(struct epoll_event, events)" -> "epoll_event_events"
      | "sizeof(struct epoll_event)" -> "epoll_event_sz"
      | name -> String.lowercase_ascii name
    in
    let v = match v with Value.Int i -> string_of_int i | _ -> assert false in
    String.concat " " [ "let"; name; "="; v ]
  in
  let defs = List.map map_to_ml defs in
  C.Flags.write_lines "epoll_cfg.ml" defs

let () =
  C.main ~name:"configure" (fun c ->
      gen_epoll_config c;
      gen_socket_config c;
      gen_error_config c)
