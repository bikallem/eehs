type t

module Int63 = Optint.Int63

module Events = struct
  type t = Int63.t
  include Config

  let none = Int63.zero
  let (+) = Int63.logor
  let mem a b = Int63.logand a b = a
  let is_none t = t = Int63.zero
end

module Op : sig
  type t

  val op_add : t
  val op_mod : t
  val op_del : t
end = struct
  type t = Int63.t

  let op_add = Config.epoll_ctl_add
  let op_mod = Config.epoll_ctl_mod
  let op_del = Config.epoll_ctl_del
end

external epoll_create : unit ->  t = "caml_epoll_create1"
external epoll_ctl : t -> Op.t -> Unix.file_descr -> Events.t -> unit = "caml_epoll_ctl"
