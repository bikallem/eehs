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

intnat
caml_errno(void)
{
  return (intnat)errno;
}

value
caml_errno_byte(void)
{
  CAMLparam0();
  CAMLreturn(Val_int(caml_errno));
}

intnat
caml_epoll_create1(void)
{
  return (intnat)epoll_create1(EPOLL_CLOEXEC);
}

value
caml_epoll_create1_byte(void)
{
  CAMLparam0();
  intnat ret = caml_epoll_create1();
  CAMLreturn(Val_int(ret));
}

value
caml_epoll_ctl(intnat epollfd, intnat op, value vfd, intnat flags)
{
  CAMLparam1(vfd);
  struct epoll_event evt;
  int fd;

  fd = Int_val(vfd);
  evt.data.ptr = NULL;
  evt.events = flags;
  evt.data.fd = fd;

  if (epoll_ctl(epollfd, op, fd, &evt) == -1)
    caml_uerror("epoll_ctl", Nothing);

  CAMLreturn(Val_unit);
}

value
caml_epoll_ctl_byte(value vepollfd, value vop, value vfd, value vflags)
{
  CAMLparam4(vepollfd, vop, vfd, vflags);
  CAMLreturn(
    caml_epoll_ctl(Int_val(vepollfd), Int_val(vop), vfd, Int_val(vflags)));
}

intnat
caml_epoll_wait(intnat epollfd,
                value vepollevents,
                intnat maxevents,
                intnat timeout)
{
  CAMLparam1(vepollevents);
  struct epoll_event* ev;
  int ret;

  ev = (struct epoll_event*)Caml_ba_data_val(vepollevents);

  if (0 == timeout) {
    ret = epoll_wait(epollfd, ev, maxevents, timeout);
  } else {
    caml_release_runtime_system();
    ret = epoll_wait(epollfd, ev, maxevents, timeout);
    caml_acquire_runtime_system();
  }

  return ret;
}

value
caml_epoll_wait_byte(value vepollfd,
                     value vepollevents,
                     value vmaxevents,
                     value vtimeout)
{
  CAMLparam4(vepollfd, vepollevents, vmaxevents, vtimeout);
  intnat ret = caml_epoll_wait(
    Int_val(vepollfd), vepollevents, Int_val(vmaxevents), Int_val(vtimeout));
  CAMLreturn(Val_int(ret));
}

value
caml_accept4(value vfd)
{
  CAMLparam1(vfd);
  CAMLlocal1(a);
  int flags;
  int retcode;
  value res;
  union sock_addr_union addr;
  socklen_param_type addr_len;

  addr_len = sizeof(addr);
  flags = SOCK_NONBLOCK | SOCK_CLOEXEC;
  retcode = accept4(Int_val(vfd), &addr.s_gen, &addr_len, flags);
  if (retcode == -1)
    caml_uerror("accept4", Nothing);

  a = caml_unix_alloc_sockaddr(&addr, addr_len, retcode);
  res = caml_alloc_small(2, 0);
  Field(res, 0) = Val_int(retcode);
  Field(res, 1) = a;
  CAMLreturn(res);
}

intnat
caml_read(value vfd, value v_buf, intnat offset, intnat len)
{
  CAMLparam2(vfd, v_buf);
  intnat ret;

  assert(offset >= 0);
  assert(offset <= (caml_string_length(v_buf) - len));
  assert(len >= 0);

  ret = (intnat)read(Int_val(vfd), Bytes_val(v_buf) + offset, len);
  if (ret == -1)
    return -(errno);

  return ret;
}

value
caml_read_byte(value v_fd, value v_buf, value v_ofs, value v_len)
{
  CAMLparam4(v_fd, v_buf, v_ofs, v_len);
  intnat ret = caml_read(v_fd, v_buf, Int_val(v_ofs), Int_val(v_len));
  CAMLreturn(Val_int(ret));
}
