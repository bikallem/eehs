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
