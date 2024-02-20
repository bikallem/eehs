#include <caml/alloc.h>
#include <caml/bigarray.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>
#include <caml/socketaddr.h>
#include <caml/unixsupport.h>
#include <sys/epoll.h>
#include <sys/socket.h>

value
caml_epoll_create1(value v_unit)
{
  int epoll_fd = epoll_create1(EPOLL_CLOEXEC);
  if (epoll_fd == -1)
    caml_uerror("epoll_create1", Nothing);

  return Val_int(epoll_fd);
}

value
caml_epoll_ctl(value v_epollfd, value v_op, value v_fd, value v_flags)
{
  struct epoll_event evt;

  evt.data.ptr = NULL;
  evt.events = Int_val(v_flags);
  evt.data.fd = Int_val(v_fd);

  if (epoll_ctl(Int_val(v_epollfd), Int_val(v_op), Int_val(v_fd), &evt) == -1)
    caml_uerror("epoll_ctl", Nothing);

  return Val_unit;
}

value
caml_epoll_wait(value v_epollfd,
                value v_epoll_events,
                value v_maxevents,
                value v_timeout_ms)
{
  CAMLparam1(v_epoll_events);
  struct epoll_event* ev;
  int retcode, timeout;

  timeout = Int_val(v_timeout_ms);
  ev = (struct epoll_event*)Caml_ba_data_val(v_epoll_events);

  if (0 == timeout) {
    retcode = epoll_wait(Int_val(v_epollfd), ev, Int_val(v_maxevents), timeout);
  } else {
    caml_enter_blocking_section();
    retcode = epoll_wait(Int_val(v_epollfd), ev, Int_val(v_maxevents), timeout);
    caml_leave_blocking_section();
  }

  if (-1 == retcode)
    caml_uerror("epoll_wait", Nothing);

  CAMLreturn(Val_int(retcode));
}
