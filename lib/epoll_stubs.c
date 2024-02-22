#define _GNU_SOURCE
#include <assert.h>
#include <caml/alloc.h>
#include <caml/bigarray.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>
#include <caml/socketaddr.h>
#include <caml/threads.h>
#include <caml/unixsupport.h>
#include <errno.h>
#include <sys/epoll.h>
#include <sys/socket.h>
#include <sys/types.h>

#define _st_uint8(v) ((const uint8_t*)(String_val(v)))

value
caml_epoll_create1(void)
{
  int epoll_fd = epoll_create1(EPOLL_CLOEXEC);
  if (epoll_fd == -1)
    caml_uerror("epoll_create1", Nothing);

  return Val_int(epoll_fd);
}

void
caml_epoll_ctl(value v_epollfd, value v_op, value v_fd, value v_flags)
{
  CAMLparam4(v_epollfd, v_op, v_fd, v_flags);
  struct epoll_event evt;

  evt.data.ptr = NULL;
  evt.events = Int_val(v_flags);
  evt.data.fd = Int_val(v_fd);

  if (epoll_ctl(Int_val(v_epollfd), Int_val(v_op), Int_val(v_fd), &evt) == -1)
    caml_uerror("epoll_ctl", Nothing);

  CAMLreturn0;
}

value
caml_epoll_wait(value v_epollfd,
                value v_epoll_events,
                value v_maxevents,
                value v_timeout_ms)
{
  CAMLparam4(v_epollfd, v_epoll_events, v_maxevents, v_timeout_ms);
  struct epoll_event* ev;
  int retcode, timeout;

  timeout = Int_val(v_timeout_ms);
  ev = (struct epoll_event*)Caml_ba_data_val(v_epoll_events);

  if (0 == timeout) {
    retcode = epoll_wait(Int_val(v_epollfd), ev, Int_val(v_maxevents), timeout);
  } else {
    caml_release_runtime_system();
    retcode = epoll_wait(Int_val(v_epollfd), ev, Int_val(v_maxevents), timeout);
    caml_acquire_runtime_system();
  }

  if (-1 == retcode)
    caml_uerror("epoll_wait", Nothing);

  CAMLreturn(Val_int(retcode));
}

value
caml_accept4(value v_cloexec, value v_fd)
{
  CAMLparam2(v_cloexec, v_fd);
  CAMLlocal1(a);
  int flags;
  int retcode;
  value res;
  union sock_addr_union addr;
  socklen_param_type addr_len;
  int clo = caml_unix_cloexec_p(v_cloexec);

  addr_len = sizeof(addr);
  flags = SOCK_NONBLOCK;
  retcode = accept4(
    Int_val(v_fd), &addr.s_gen, &addr_len, clo ? SOCK_CLOEXEC | flags : flags);
  if (retcode == -1)
    caml_uerror("accept4", Nothing);
  a = caml_unix_alloc_sockaddr(&addr, addr_len, retcode);
  res = caml_alloc_small(2, 0);
  Field(res, 0) = Val_int(retcode);
  Field(res, 1) = a;
  CAMLreturn(res);
}

value
caml_read(value v_fd, value v_buf, value v_ofs, value v_len)
{
  CAMLparam4(v_fd, v_buf, v_ofs, v_len);
  int ret, offset, len;

  offset = Int_val(v_ofs);
  len = Int_val(v_len);

  assert(offset >= 0);
  assert(offset <= (caml_string_length(v_buf) - len));
  assert(len >= 0);

  ret = read(Int_val(v_fd), Bytes_val(v_buf) + offset, len);
  if (ret == -1)
    ret = -(errno);

  CAMLreturn(Val_int(ret));
}
