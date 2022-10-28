type t

module Flag : sig
  type t

  val epoll_ctl_add : t
  val epoll_ctl_mod : t
  val epoll_ctl_del : t
  val epollin : t
  val epollout : t
  val epollrdhup : t
  val epollpri : t
  val epollerr : t
  val epollhup : t
  val epollet : t
  val epolloneshot: t
  val epollwakeup : t
  val epollexclusive: t
end

val epoll_create : unit -> t 
