#include <sys/epoll.h>

#include <caml/alloc.h>
#include <caml/bigarray.h>
#include <caml/fail.h>
#include <caml/mlvalues.h>
#include <caml/unixsupport.h>
#include <caml/socketaddr.h>
#include <sys/socket.h>

value caml_epoll_create1(value close_on_exec)
{
  int t;
  int flags = 0;
  if (Bool_val(close_on_exec)) {
    flags |= EPOLL_CLOEXEC;
  }
  t = epoll_create1(flags);
  if (t == -1) caml_uerror("epoll_create1", Nothing); 
  return (Val_int(t));
}
