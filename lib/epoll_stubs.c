#include <sys/epoll.h>
#include <sys/socket.h>

#include <caml/alloc.h>
#include <caml/bigarray.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>
#include <caml/socketaddr.h>
#include <caml/unixsupport.h>

value caml_epoll_create1(value v_unit) {
  int t;

  t = epoll_create1(EPOLL_CLOEXEC);
  if (t == -1)
    caml_uerror("epoll_create1", Nothing);

  return Val_int(t);
}

value caml_epoll_ctl(value v_epollfd, value v_op, value v_fd, value v_flags) {
  struct epoll_event evt;

  evt.events = Int_val(v_flags);
  evt.data.ptr = NULL;
  evt.data.fd = Int_val(v_fd);

  if (epoll_ctl(Int_val(v_epollfd), Int_val(v_op), Int_val(v_fd), &evt) == -1)
    caml_uerror("epoll_ctl", Nothing);

  return Val_unit;
}

value caml_epoll_wait(value v_epollfd,
                      value v_epoll_events,
                      value v_maxevents,
                      value v_timeout_ms) {
  struct epoll_event* ev;
  int retcode, maxevents, timeout;

  timeout = Int_val(v_timeout_ms);
  maxevents = Int_val(v_maxevents);

  CAMLparam1(v_epoll_events);

  ev = (struct epoll_event*)Caml_ba_data_val(v_epoll_events);

  if (0 == timeout) {
    retcode = epoll_wait(Int_val(v_epollfd), ev, maxevents, timeout);
  } else {
    caml_enter_blocking_section();
    retcode = epoll_wait(Int_val(v_epollfd), ev, maxevents, timeout);
    caml_leave_blocking_section();
  }

  if (-1 == retcode)
    caml_uerror("epoll_wait", Nothing);

  CAMLreturn(Int_val(retcode));
}
