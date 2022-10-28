type t

external epoll_create1 : unit ->  t = "caml_epoll_create1"
(* external epoll_ctl : t -> op -> Unix.file_descr -> unit = "caml_epoll_ctl" *)
