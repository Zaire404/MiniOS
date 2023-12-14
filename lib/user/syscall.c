#include "syscall.h"

#define _syscall0(NUMBER) ({ \
    int retval; \
    asm volatile ( \
        "int $0x80" \
        : "=a" (retval) \
        : "a" (NUMBER) \
        : "memory" \
    ); \
    retval; \
})

#define _syscall1(NUMBER, ARG1) ({ \
    int retval; \
    asm volatile ( \
        "int $0x80" \
        : "=a" (retval) \
        : "a" (NUMBER), "b" (ARG1) \
        : "memory" \
    ); \
    retval; \
})

#define _syscall2(NUMBER, ARG1, ARG2) ({ \
    int retval; \
    asm volatile ( \
        "int $0x80" \
        : "=a" (retval) \
        : "a" (NUMBER), "b" (ARG1), "c" (ARG2) \
        : "memory" \
    ); \
    retval; \
})

#define _syscall3(NUMBER, ARG1, ARG2, ARG3) ({ \
    int retval; \
    asm volatile ( \
        "int $0x80" \
        : "=a" (retval) \
        : "a" (NUMBER), "b" (ARG1), "c" (ARG2), "d" (ARG3) \
        : "memory" \
    ); \
    retval; \
})

uint32_t getpid(void) {
    return _syscall0(SYS_GETPID);
}

// 打印字符串
uint32_t write(char* str) {
    return _syscall1(SYS_WRITE, str);
}

// 分配size字节大小的内存, 并返回结果
void* malloc(uint32_t size) {
    return (void*)_syscall1(SYS_MALLOC, size);
}

// 释放ptr指向的内存
void free(void* ptr) {
    _syscall1(SYS_FREE, ptr);
}
