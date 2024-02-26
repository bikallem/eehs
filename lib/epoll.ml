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

external accept4 : Unix.file_descr -> int * Unix.sockaddr option
  = "caml_accept4"

external read :
  Unix.file_descr ->
  bytes ->
  (int[@untagged]) ->
  (int[@untagged]) ->
  (int[@untagged]) = "caml_read_byte" "caml_read"
[@@noalloc]

let _traceln fmt = Format.(fprintf std_formatter ("\n+" ^^ fmt ^^ "%!"))

(* external caml_accept4_2 : *)
(*   Unix.file_descr -> flags[@untagged]) -> (int[@untagged]) *)
(*   = "caml_accept4_2_byte" "caml_accept4_2" *)
(* [@@noalloc] *)

(* external inet_addr_of_raw_bytes : string -> Unix.inet_addr = "%identity" *)

(* module Sockaddr = struct *)
(*   type addr = bytes (1* struct sockaddr_storage *1) *)
(*   type addrlen = int (1* sizeof(addr) *1) *)
(*   type t = addr * addrlen *)

(* let c_strnlen buf ofs maxlen = *)
(*   if ofs == maxlen then maxlen *)
(*   else if Bytes.get_uint8 buf ofs == 0 then ofs + 1 *)
(*   else c_strnlen buf (ofs + 1) maxlen *)

(* let strlen = ref 0 in *)
(* for i = 0 to len do *)
(*   if Bytes.get_uint8 buf i == 0 then *)
(* done; *)
(* Bytes.sub_string buf 0 *)

(* let decode_unixdomain_sockaddr (addr, addrlen) = *)

(* let to_sockaddr (addr, _addrlen) = *)
(*   let ss_family = Bytes.get_int16_le addr Sock_cfg.sa_ss_family_ofs in *)
(*   if ss_family = Sock_cfg.af_inet then *)
(*     let inet_addr = *)
(*       Bytes.sub_string addr Sock_cfg.sin_addr_ofs Sock_cfg.in_addr_sz *)
(*       |> inet_addr_of_raw_bytes *)
(*     in *)
(*     (1* _traceln "sin_port_ofs: %i" Sock_cfg.sin_port_ofs; *1) *)
(*     let port = Bytes.get_int16_le addr 2 in *)
(*     Unix.ADDR_INET (inet_addr, port) *)
(*   else if ss_family = Sock_cfg.af_inet6 then *)
(*     let inet6_addr = *)
(*       Bytes.sub_string addr Sock_cfg.sin6_addr_ofs Sock_cfg.in6_addr_sz *)
(*       |> inet_addr_of_raw_bytes *)
(*     in *)
(*     let port = Bytes.get_int16_le addr Sock_cfg.sin6_port_ofs in *)
(*     Unix.ADDR_INET (inet6_addr, port) *)
(*   else raise @@ Unix.(Unix_error (EAFNOSUPPORT, "", "")) *)
(* end *)

(* let accept4_2 fd = *)
(*   let addrlen = Sock_cfg.sockaddr_storage_sz in *)
(*   let sockaddr = Bytes.make addrlen '\000' in *)
(*   let addrlen_ref = Bytes.make Sock_cfg.socklen_t_sz '\000' in *)
(*   Bytes.set_int32_le addrlen_ref 0 (Int32.of_int addrlen); *)
(*   let flags = Sock_cfg.(sock_nonblock lor sock_cloexec) in *)
(*   let ret = caml_accept4_2 fd sockaddr addrlen_ref flags in *)
(*   if ret = -1 then raise @@ Error.raise_syscall_error "accept4" *)
(*   else *)
(*     let fd = file_descr_of_int ret in *)
(*     let addrlen = Bytes.get_int32_le addrlen_ref 0 in *)
(*     _traceln "addrlen %li" addrlen; *)
(*     (fd, (sockaddr, Int32.to_int addrlen)) *)

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
