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

value
caml_epoll_ctl(value v_epollfd, value v_op, value v_fd, value v_flags)
{
  CAMLparam4(v_epollfd, v_op, v_fd, v_flags);
  struct epoll_event evt;

  evt.data.ptr = NULL;
  evt.events = Int_val(v_flags);
  evt.data.fd = Int_val(v_fd);

  if (epoll_ctl(Int_val(v_epollfd), Int_val(v_op), Int_val(v_fd), &evt) == -1)
    caml_uerror("epoll_ctl", Nothing);

  CAMLreturn(Val_unit);
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

  if (-1 == ret)
    return -(errno);

  /* caml_uerror("epoll_wait", Nothing); */
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
