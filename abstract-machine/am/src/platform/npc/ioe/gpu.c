#include <am.h>
#include <npc.h>

#define SYNC_ADDR (VGACTL_ADDR + 4)

void __am_gpu_init() { /* do nothing */ }

/// @param cfg return the screen width and height
void __am_gpu_config(AM_GPU_CONFIG_T *cfg) {
  // FIXME: hardcode the screen width and height
  *cfg = (AM_GPU_CONFIG_T){ .present = true, .has_accel = false, .width = 640, .height = 480, .vmemsz = (1 << 19) };
}

void __am_gpu_fbdraw(AM_GPU_FBDRAW_T *ctl) {
  int x = ctl->x, y = ctl->y;  // 绘图的起点坐标 (x, y)
  int w = ctl->w, h = ctl->h;  // 绘图的宽高 (w, h)
  if (!ctl->sync && (w == 0 || h == 0)) { return; } // 啥也没干, 直接返回
  uint32_t *pixels = ctl->pixels; // 绘图的数据
  if (pixels == NULL && !(w == 0 && h == 0)) { return; } // 非法数据, 让你绘制图像, 但是没告诉你绘制啥
  uint32_t *fb = (uint32_t *)(uintptr_t)FB_ADDR; // 显存地址
  uint32_t screen_w = 640; // 屏幕的宽度
  volatile uint32_t *dst = fb + screen_w * y + x; // dst 指向显存
  uint32_t *src = pixels;
  for (size_t i = 0; i < h; i++) { // 逐行复制
    for (size_t j = 0; j < w; j++) { dst[j] = src[j]; }
    dst += screen_w;
    src += w;
  }
  if (ctl->sync) { // 是否立刻刷新到显示器上, 否则只是在显存中更新了数据, 但是没有显示
    outl(SYNC_ADDR, 1);
  }
}

void __am_gpu_status(AM_GPU_STATUS_T *status) {
  status->ready = true;
}
