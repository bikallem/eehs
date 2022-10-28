type t

module Flag = struct
  type t = int
  include Config
end

external epoll_create : unit ->  t = "caml_epoll_create1"
(* external epoll_ctl : t -> op -> Unix.file_descr -> unit = "caml_epoll_ctl" *)
