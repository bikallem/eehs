module Io_events : sig
  type t

  val readable : t
  val writable : t

  val rw : t
  (** [rw] is [readable + writable] *)

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
val poll_io : ?timeout_ms:int -> t -> unit
val iter : t -> (Unix.file_descr -> Io_events.t -> unit) -> unit
