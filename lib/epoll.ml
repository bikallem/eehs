type epoll_events = Cstruct.buffer
type timeout_ms = int
type maxevents = int

module C_epoll = struct
  type epoll_fd

  module Events : sig
    type t

    val ( + ) : t -> t -> t
    val mem : t -> t -> bool
    val is_none : t -> bool
    val none : t
    val epollin : t
    val epollout : t
    val epollpri : t
    val epollerr : t
    val epollhup : t
    val epollet : t
    val epolloneshot : t
  end = struct
    type t = int

    include Config

    let none = 0
    let ( + ) = Int.logor
    let mem a b = Int.logand a b = a
    let is_none t = t = 0
  end

  module Op : sig
    type t

    val op_add : t
    val op_mod : t
    val op_del : t
  end = struct
    type t = int

    let op_add = Config.epoll_ctl_add
    let op_mod = Config.epoll_ctl_mod
    let op_del = Config.epoll_ctl_del
  end

  external epoll_create : unit -> epoll_fd = "caml_epoll_create1"

  external epoll_ctl : epoll_fd -> Op.t -> Unix.file_descr -> Events.t -> unit
    = "caml_epoll_ctl"

  external epoll_wait :
    epoll_fd -> epoll_events -> maxevents -> timeout_ms -> int
    = "caml_epoll_pwait"
end

type t = {
  epollfd : C_epoll.epoll_fd;
  max_ready_events : int;
  epoll_events : Cstruct.t;
  mutable num_ready_events : int;
}

let create max_ready_events =
  {
    epollfd = C_epoll.epoll_create ();
    max_ready_events;
    epoll_events = Cstruct.create (Config.sizeof_epoll_event * max_ready_events);
    num_ready_events = 0;
  }
