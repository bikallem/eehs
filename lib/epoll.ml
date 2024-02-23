type epoll_events = Base_bigstring.t
type timeout_ms = int
type maxevents = int
type epoll_fd = int

module Op : sig
  type t = int

  val op_add : t
  val op_mod : t
  val op_del : t
end = struct
  type t = int

  let op_add = Config.epoll_ctl_add
  let op_mod = Config.epoll_ctl_mod
  let op_del = Config.epoll_ctl_del
end

(* epoll syscalls *)

external caml_epoll_create : unit -> (epoll_fd[@untagged])
  = "caml_epoll_create1_byte" "caml_epoll_create1"
[@@noalloc]

external caml_epoll_ctl :
  (epoll_fd[@untagged]) ->
  (Op.t[@untagged]) ->
  Unix.file_descr ->
  (int[@untagged]) ->
  (int[@untagged]) = "caml_epoll_ctl_byte" "caml_epoll_ctl"
[@@noalloc]

external caml_epoll_wait :
  (epoll_fd[@untagged]) ->
  epoll_events ->
  (maxevents[@untagged]) ->
  (timeout_ms[@untagged]) ->
  (int[@untagged]) = "caml_epoll_wait_byte" "caml_epoll_wait"

external file_descr_of_int : int -> Unix.file_descr = "%identity"

(* IO syscalls *)

external accept4 : Unix.file_descr -> Unix.file_descr * Unix.sockaddr
  = "caml_accept4"

external read :
  Unix.file_descr ->
  bytes ->
  (int[@untagged]) ->
  (int[@untagged]) ->
  (int[@untagged]) = "caml_read_byte" "caml_read"
[@@noalloc]

(* external unsafe_write : Unix.file_descr -> string -> int -> int -> int *)
(*   = "caml_write" *)

(* let write fd s ofs len = *)
(*   if ofs < 0 || len < 0 || ofs > String.length s - len then *)
(*     invalid_arg "Epoll.write" *)
(*   else unsafe_write fd s ofs len *)

module Io_events = struct
  type t = int

  let add = ( lor )
  let ( + ) = add
  let remove a b = a land lnot b
  let read = Config.epollin
  let write = Config.epollout
  let rw = read lor write
  let readable t = t land Config.epollin = Config.epollin
  let writable t = t land Config.epollout = Config.epollout

  let read_closed t =
    t land Config.epollhup = t || (readable t && t land Config.epollrdhup = t)

  let write_closed t =
    t land Config.epollhup = t || (writable t && t land Config.epollrdhup = t)

  let error t = t land Config.epollerr = t
end

type t = {
  epollfd : epoll_fd;
  maxevents : maxevents;
  epoll_events : epoll_events;
  mutable num_ready_events : int;
}

let create maxevents =
  let epollfd = caml_epoll_create () in
  if epollfd = -1 then Error.raise_syscall_error "epoll_create1";
  {
    epollfd;
    maxevents;
    epoll_events = Base_bigstring.create (Config.sizeof_epoll_event * maxevents);
    num_ready_events = 0;
  }

let add t fd io_events =
  if caml_epoll_ctl t.epollfd Op.op_add fd io_events = -1 then
    Error.raise_syscall_error "epoll_ctl"

let modify t fd io_events =
  if caml_epoll_ctl t.epollfd Op.op_mod fd io_events = -1 then
    Error.raise_syscall_error "epoll_ctl"

let remove t fd : unit =
  if caml_epoll_ctl t.epollfd Op.op_del fd 0 = -1 then
    Error.raise_syscall_error "epoll_ctl"

let epoll_wait ?(timeout_ms = 0) (t : t) =
  t.num_ready_events <- 0;
  let ready = caml_epoll_wait t.epollfd t.epoll_events t.maxevents timeout_ms in
  if ready = -1 then Error.raise_syscall_error "epoll_wait";
  t.num_ready_events <- ready

let ready_fd epoll_events i =
  Base_bigstring.unsafe_get_int32_le epoll_events
    ~pos:((i * Config.sizeof_epoll_event) + Config.offsetof_epoll_fd)
  |> file_descr_of_int

let io_events epoll_events i =
  Base_bigstring.unsafe_get_int32_le epoll_events
    ~pos:(i * Config.sizeof_epoll_event * Config.offsetof_epoll_events)

let iter t f =
  for i = 0 to t.num_ready_events - 1 do
    f (ready_fd t.epoll_events i) (io_events t.epoll_events i)
  done
