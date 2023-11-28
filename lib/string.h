#ifndef __LIB_STRING_H
#define __LIB_STRING_H
#define NULL 0
#include "stdint.h"

void memset(void* dst_, uint8_t value, uint32_t size);      // dst起始size字节置为value
void memcpy(void* dst_, const void* src_, uint32_t size);   // src起始size字节复制到dst
int memcmp(const void* a_, const void* b_, uint32_t size);  // 连续比较a_和b_开头的size字节，相等返回0
char* strcpy(char* dst_, const char* src_);                 // 将字符串从src_复制到dst_
uint32_t strlen(const char* str);                           // 返回字符串长度
int8_t strcmp(const char* a, const char* b);                // 比较两个字符串
char* strchr(const char* str, const uint8_t ch);            // 查找字符首次出现的地址
char* strrchr(const char* str, const uint8_t ch);           // 反向查找字符地址
char* strcat(char* dst_, const char* src_);                 // 拼接字符串
uint32_t strchrs(const char* str, uint8_t ch);              // 查找字符出现次数

#endif