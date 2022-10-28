type t

module Events = struct
  type t = int
  include Config

  let none = 0
  let (+) = ( lor )
  let mem a b = (a land b) = a
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

external epoll_create : unit ->  t = "caml_epoll_create1"
external epoll_ctl : t -> Op.t -> Unix.file_descr -> Events.t -> unit = "caml_epoll_ctl"
