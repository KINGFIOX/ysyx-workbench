extern void _trm_init(void);

extern char _app_lma;
extern char _app_vma_start;
extern char _app_vma_end;
extern char _bss_start;
extern char _bss_end;

void ssbl(void) {
  // copy .text, .rodata, .data from flash(xip) to sdram
  volatile char *src = &_app_lma;
  volatile char *dst = &_app_vma_start;
  volatile char *end = &_app_vma_end;
  while (dst < end) {
    *dst++ = *src++;
  }

  // clear .bss
  dst = &_bss_start;
  end = &_bss_end;
  while (dst < end) {
    *dst++ = 0;
  }

  _trm_init();
}
