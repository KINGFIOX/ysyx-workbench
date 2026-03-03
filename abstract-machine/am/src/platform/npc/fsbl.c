extern void ssbl(void);

extern char _ssbl_lma;
extern char _ssbl_vma_start;
extern char _ssbl_vma_end;

void fsbl(void) {
  // copy .text, .rodata from flash(xip) to sdram
  volatile char *src = &_ssbl_lma;
  volatile char *dst = &_ssbl_vma_start;
  volatile char *end = &_ssbl_vma_end;
  while (dst < end) {
    *dst++ = *src++;
  }

  ssbl();
}
