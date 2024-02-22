(** [Io_events] is a set of Input/Output events that is monitored by epoll. *)
module Io_events : sig
  type t

  val read : t
  (** [read] is [t] which contains EPOLLIN event. *)

  val write : t
  (** [write] is [t] which conatsin EPOLLOUT event. *)

  val rw : t
  (** [rw] is [read + write] *)

  val add : t -> t -> t
  val ( + ) : t -> t -> t
  val remove : t -> t -> t
  val is_readable : t -> bool
  val is_writable : t -> bool
  val is_read_closed : t -> bool
  val is_write_closed : t -> bool
  val is_error : t -> bool
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

val accept4 :
  ?cloexec:bool -> Unix.file_descr -> Unix.file_descr * Unix.sockaddr

val read : Unix.file_descr -> bytes -> int -> int -> int [@@noalloc]
(* val write : Unix.file_descr -> string -> int -> int -> int *)
