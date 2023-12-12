#ifndef __LIB_STDIO_H__
#define __LIB_STDIO_H__
#include "global.h"
typedef char* va_list;
uint32_t printf(const char* str, ...);
uint32_t vsprintf(char* buf, const char* format, va_list ap);
#endif