#include <sys/epoll.h>

#include <caml/alloc.h>
#include <caml/bigarray.h>
#include <caml/fail.h>
#include <caml/mlvalues.h>
#include <caml/unixsupport.h>
#include <caml/socketaddr.h>
#include <sys/socket.h>

/* https://github.com/janestreet/jane-street-headers/blob/2601ed3b084493683ed0166e24f7939004a7c057/include/ocaml_utils.h#L26 */
#ifdef ARCH_SIXTYFOUR
  #define Val_int63(v) Val_long(v)
  #define Int63_val(v) Long_val(v)
#else
/* On 32bit architectures, an OCaml [int63] is represented as a 64 bit
 * integer with its bits shifted to the left and the least significant bit set to 0.
 * It makes int64 arithmetic operations work on [int63] with proper overflow handling.
 */
  #define Val_int63(v) caml_copy_int64(((int64_t) (v)) << 1)
  #define Int63_val(v) (Int64_val(v)) >> 1
#endif

value caml_epoll_create1(value v_unit)
{
  int t;

  t = epoll_create1(EPOLL_CLOEXEC);
  if (t == -1) caml_uerror("epoll_create1", Nothing);

  return Val_int(t);
}

value caml_epoll_ctl(value v_epollfd, value v_op, value v_fd, value v_flags)
{
  struct epoll_event evt;

  evt.events = Int63_val(v_flags);
  evt.data.ptr = NULL;
  evt.data.fd = Long_val(v_fd);

  if (epoll_ctl(Long_val(v_epollfd), Int63_val(v_op), Long_val(v_fd), &evt) == -1)
    caml_uerror("epoll_ctl", Nothing);

  return Val_unit;
}

value caml_epoll_pwait(value v_epollfd, value v_epoll_events, value v_maxevents, value v_timeoutns)
{
  
  return Val_int(0);
}
