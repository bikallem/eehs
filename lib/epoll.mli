type t

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
end

module Op : sig
  type t

  val op_add : t
  val op_mod : t
  val op_del : t
end

type epoll_events = Cstruct.buffer
type timeout_ns = Optint.Int63.t
type maxevents = Optint.Int63.t

val epoll_create : unit -> t
val epoll_ctl : t -> Op.t -> Unix.file_descr -> Events.t -> unit
val epoll_wait : t -> epoll_events -> maxevents -> timeout_ns -> int
