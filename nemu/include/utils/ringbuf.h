/***************************************************************************************
 * Copyright (c) 2014-2024 Zihao Yu, Nanjing University
 *
 * NEMU is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan
 *PSL v2. You may obtain a copy of Mulan PSL v2 at:
 *          http://license.coscl.org.cn/MulanPSL2
 *
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
 *KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
 *NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 *
 * See the Mulan PSL v2 for more details.
 ***************************************************************************************/

#ifndef __UTILS_RINGBUF_H__
#define __UTILS_RINGBUF_H__

#include <stddef.h>

#define RINGBUF_DEFINE(item_type, capacity) \
  struct { \
    item_type items[capacity]; \
    size_t ptr; \
    size_t count; \
  }

#define RINGBUF_INIT { .ptr = 0, .count = 0 }

#define RINGBUF_PUSH(rb, capacity, item) \
  do { \
    (rb).items[(rb).ptr] = (item); \
    if ((rb).count < (capacity)) { \
      (rb).count++; \
    } \
    (rb).ptr = ((rb).ptr + 1) % (capacity); \
  } while (0)


#define RINGBUF_EMPTY(rb) ((rb).count == 0)

#define RINGBUF_COUNT(rb) ((rb).count)

#define RINGBUF_GET(rb, pos) (&(rb).items[pos])

#define RINGBUF_START(rb, capacity) (((rb).ptr + (capacity) - (rb).count) % (capacity))
#define RINGBUF_FOREACH(rb, capacity, idx, pos) \
  for (size_t idx = 0, pos = RINGBUF_START(rb, capacity), _ringbuf_valid = (rb).count; \
       idx < _ringbuf_valid; \
       idx++, pos = (pos + 1) % (capacity))

#define RINGBUF_IS_LAST(rb, idx) ((idx) == (rb).count - 1)

#endif
