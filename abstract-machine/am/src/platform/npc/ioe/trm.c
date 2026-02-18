#include <am.h>
#include <npc.h>

extern char _heap_start;
int main(const char *args);

Area heap = RANGE(&_heap_start, PMEM_END);
static const char mainargs[MAINARGS_MAX_LEN] = TOSTRING(MAINARGS_PLACEHOLDER); // defined in CFLAGS

#define UART_BASE 0x10000000
// UART 16550 寄存器定义
#define UART_THR (UART_BASE + 0) // Transmit Holding Register (DLAB=0)
#define UART_RBR (UART_BASE + 0) // Receiver Buffer Register (DLAB=0)
#define UART_DLL (UART_BASE + 0) // Divisor Latch Low (DLAB=1)
#define UART_DLM (UART_BASE + 1) // Divisor Latch High (DLAB=1)
#define UART_IER (UART_BASE + 1) // Interrupt Enable Register (DLAB=0)
#define UART_FCR (UART_BASE + 2) // FIFO Control Register (写)
#define UART_LCR (UART_BASE + 3) // Line Control Register
#define UART_LSR (UART_BASE + 5) // Line Status Register

// LCR 位定义
#define LCR_DLAB 0x83u // Divisor Latch Access Bit
#define LCR_8N1  0x03u // 8 data bits, no parity, 1 stop bit

// FCR 位定义
#define FCR_FIFO_ENABLE 0x01u // FIFO Enable (ignored)
#define FCR_RX_RESET    0x02u // Receiver FIFO Reset
#define FCR_TX_RESET    0x04u // Transmitter FIFO Reset

// LSR 位定义
#define LSR_DR   0x01u // Data Ready
#define LSR_THRE 0x20u // Transmitter Holding Register Empty
#define LSR_TEMT 0x40u // Transmitter Empty

static void uart_init(void) {
  volatile char *lcr = (volatile char *)UART_LCR;
  volatile char *dll = (volatile char *)UART_DLL;
  volatile char *dlm = (volatile char *)UART_DLM;
  volatile char *fcr = (volatile char *)UART_FCR;
  volatile char *ier = (volatile char *)UART_IER;

  // 1. 禁用所有中断
  *ier = 0x00;

  // 2. 使能 DLAB 以设置波特率
  *lcr = LCR_DLAB;
  *dll = 0x01; // Divisor Latch Low
  *dlm = 0x00; // Divisor Latch High

  // 3. 禁用 DLAB，设置数据格式: 8N1 (8数据位, 无奇偶校验, 1停止位)
  *lcr = LCR_8N1; // 8bit, no parity, 1 stop bit, disable setting BAUD rate

  // 4. 使能并复位 FIFO
  *fcr = FCR_FIFO_ENABLE | FCR_RX_RESET | FCR_TX_RESET;
}

void putch(char ch) {
  volatile char *thr = (volatile char *)UART_THR;
  volatile char *lsr = (volatile char *)UART_LSR;

  // 等待发送 FIFO 有空间 (THRE=1 表示可以写入)
  while ((*lsr & LSR_THRE) == 0)
    ;

  *thr = ch;
}

void halt(int code) {
  ebreak(code);

  // should not reach here
  while (1);
}

void _trm_init() {
  uart_init();
  int ret = main(mainargs);
  halt(ret);
}
