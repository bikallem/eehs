#include <sys/epoll.h>

#include <caml/alloc.h>
#include <caml/bigarray.h>
#include <caml/fail.h>
#include <caml/mlvalues.h>
#include <caml/unixsupport.h>
#include <caml/socketaddr.h>
#include <sys/socket.h>

value caml_epoll_create1(value v_unit)
{
  int t;

  t = epoll_create1(EPOLL_CLOEXEC);
  if (t == -1) caml_uerror("epoll_create1", Nothing);

  return Val_int(t);
}

value caml_epoll_ctl(value v_epoll_fd, value v_op, value v_fd, value v_flags)
{
  struct epoll_event evt;

  evt.events = Int_val(v_flags);
  evt.data.ptr = NULL;
  evt.data.fd = Int_val(v_fd);

  if (epoll_ctl(Int_val(v_epoll_fd), Int_val(v_op), Int_val(v_fd), &evt) == -1)
    caml_uerror("epoll_ctl", Nothing);

  return Val_unit;
}
