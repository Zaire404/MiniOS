#ifndef __DEVICE_TIMER_H
#define __DEVICE_TIMER_H
#include "stdint.h"
void timer_init(void);
void mtime_sleep(uint32_t m_seconds);
#endif