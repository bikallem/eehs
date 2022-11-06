module Io_events : sig
  type t

  val readable : t
  val writable : t
  val add : t -> t -> t
  val remove : t -> t -> t
  val is_readable : t -> bool
  val is_writable : t -> bool
end

type t

val create : int -> t
val add : t -> Unix.file_descr -> Io_events.t -> unit
val modify : t -> Unix.file_descr -> Io_events.t -> unit
val remove : t -> Unix.file_descr -> unit
val poll_io : ?timeout_ms:int -> t -> [ `Ok | `Timeout ]
val iter : (Unix.file_descr -> Io_events.t -> unit) -> t -> unit
