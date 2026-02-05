#include <am.h>
#include <npc.h>

extern char _heap_start;
int main(const char *args);

Area heap = RANGE(&_heap_start, PMEM_END);
static const char mainargs[MAINARGS_MAX_LEN] = TOSTRING(MAINARGS_PLACEHOLDER); // defined in CFLAGS

#define UART_BASE 0x10000000
#define UART_THR (UART_BASE + 0) // Transmit Holding Register (DLAB=0)

void putch(char ch) {
  volatile char *thr = (volatile char *)UART_THR;
  *thr = ch;
}

void halt(int code) {
  ebreak(code);

  // should not reach here
  while (1);
}

void _trm_init() {
  int ret = main(mainargs);
  halt(ret);
}
