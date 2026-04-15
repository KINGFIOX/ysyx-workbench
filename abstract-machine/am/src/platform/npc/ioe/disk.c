#include <am.h>
#include <npc.h>
#include <klib.h>

extern unsigned char _ramdisk_start[];
extern unsigned char _ramdisk_end[];

#define DISK_BLK_SIZE 512

void __am_disk_config(AM_DISK_CONFIG_T *cfg) {
  cfg->present = (&_ramdisk_end != &_ramdisk_start);
  cfg->blksz = DISK_BLK_SIZE;
  cfg->blkcnt = (_ramdisk_end - _ramdisk_start) / DISK_BLK_SIZE;
}

void __am_disk_status(AM_DISK_STATUS_T *stat) {
  stat->ready = true;
}

void __am_disk_blkio(AM_DISK_BLKIO_T *io) {
  uint8_t *base = _ramdisk_start + (uint64_t)io->blkno * DISK_BLK_SIZE;
  uint32_t len = (uint32_t)io->blkcnt * DISK_BLK_SIZE;
  if (io->write)
    memcpy(base, io->buf, len);
  else
    memcpy(io->buf, base, len);
}
