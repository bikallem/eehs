type t

module Events : sig
  type t

  val (+) : t -> t -> t
  val mem : t -> t -> bool
  val is_none : t -> bool

  val none : t
  val epollin : t
  val epollout : t
  val epollpri : t
  val epollerr : t
  val epollhup : t
  val epollet : t
  val epolloneshot: t
end

module Op : sig
  type t

  val op_add : t
  val op_mod : t
  val op_del : t
end

val epoll_create : unit -> t 
val epoll_ctl : t -> Op.t -> Unix.file_descr -> Events.t -> unit
