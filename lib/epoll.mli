(** [Io_events] is a set of Input/Output events that is monitored by epoll. *)
module Io_events : sig
  type t = private int

  val read : t
  (** [read] is [t] which contains EPOLLIN event. *)

  val write : t
  (** [write] is [t] which conatsin EPOLLOUT event. *)

  val rw : t
  (** [rw] is [read + write] *)

  val add : t -> t -> t
  val ( + ) : t -> t -> t
  val remove : t -> t -> t
  val readable : t -> bool
  val writable : t -> bool
  val read_closed : t -> bool
  val write_closed : t -> bool
  val error : t -> bool
end

type t
(** Represents Linux epoll object. *)

val create : int -> t
(** [create maxevents] is [t] which can listen to at most [maxevents] ojects *)

val add : t -> Unix.file_descr -> Io_events.t -> unit
val modify : t -> Unix.file_descr -> Io_events.t -> unit
val remove : t -> Unix.file_descr -> unit
val epoll_wait : ?timeout_ms:int -> t -> unit
val iter : t -> (Unix.file_descr -> Io_events.t -> unit) -> unit

(** IO *)

external file_descr_of_int : int -> Unix.file_descr = "%identity"

external accept4 : Unix.file_descr -> int * Unix.sockaddr option
  = "caml_accept4"

(* Similar to Unix.sockaddr but lazy loaded *)
(* module Sockaddr : sig *)
(*   type t *)

(*   val to_sockaddr : t -> Unix.sockaddr *)
(* end *)

(* val accept4_2 : Unix.file_descr -> Unix.file_descr * Sockaddr.t *)

external read :
  Unix.file_descr ->
  bytes ->
  (int[@untagged]) ->
  (int[@untagged]) ->
  (int[@untagged]) = "caml_read_byte" "caml_read"
[@@noalloc]

(* val write : Unix.file_descr -> string -> int -> int -> int *)
