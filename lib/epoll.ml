type epoll_events = Cstruct.buffer
type timeout_ms = int
type maxevents = int
type epoll_fd

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

external epoll_ctl : epoll_fd -> Op.t -> Unix.file_descr -> int -> unit
  = "caml_epoll_ctl"

external epoll_wait : epoll_fd -> epoll_events -> maxevents -> timeout_ms -> int
  = "caml_epoll_wait"

module Io_events = struct
  type t = int

  let add = ( lor )
  let remove a b = a land lnot b
  let readable = Config.epollin
  let writable = Config.epollout
  let is_readable t = t land readable = t
  let is_writable t = t land writable = t
end

type t =
  { epollfd: epoll_fd
  ; maxevents: maxevents
  ; epoll_events: Cstruct.t
  ; mutable num_ready_events: int }

let create maxevents =
  { epollfd= epoll_create ()
  ; maxevents
  ; epoll_events= Cstruct.create (Config.sizeof_epoll_event * maxevents)
  ; num_ready_events= 0 }

let add t fd io_events = epoll_ctl t.epollfd Op.op_add fd io_events
let modify t fd io_events = epoll_ctl t.epollfd Op.op_mod fd io_events
let remove t fd : unit = epoll_ctl t.epollfd Op.op_del fd 0

let poll_io ?(timeout_ms = 0) (t : t) : [`Ok | `Timeout] =
  t.num_ready_events <-
    epoll_wait t.epollfd
      (Cstruct.to_bigarray t.epoll_events)
      t.maxevents timeout_ms ;
  if t.num_ready_events = 0 then `Timeout else `Ok
