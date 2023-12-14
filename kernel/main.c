#include "console.h"
#include "debug.h"
#include "init.h"
#include "interrupt.h"
#include "ioqueue.h"
#include "keyboard.h"
#include "memory.h"
#include "process.h"
#include "stdio.h"
#include "syscall-init.h"
#include "syscall.h"
#include "thread.h"

void k_thread_a(void*);
void k_thread_b(void*);
void u_prog_a(void);
void u_prog_b(void);
int prog_a_pid = 0, prog_b_pid = 0;

int main(void) {
    init_all();
    process_execute(u_prog_a, "user_prog_a");
    process_execute(u_prog_b, "user_prog_b");
    intr_enable();
    thread_start("consumer_a", 31, k_thread_a, "argA ");
    thread_start("consumer_b", 31, k_thread_b, "argB ");
    while (1) {
    };
    return 0;
}

void k_thread_a(void* arg) {
    char* para = arg;
    void* addr = sys_malloc(33);
    console_put_str(" I am thread_a, sys_malloc(33), addr is 0x");
    console_put_int((int)addr);
    console_put_char('\n');
    while (1) {
    }
}
void k_thread_b(void* arg) {
    char* para = arg;
    void* addr = sys_malloc(63);
    console_put_str(" I am thread_b, sys_malloc(63), addr is 0x");
    console_put_int((int)addr);
    console_put_char('\n');
    while (1) {
    }
}

void u_prog_a(void) {
    char* name = "prog_a";
    printf(" I am %s, my pid:%d%c", name, getpid(), '\n');
    while (1) {
    }
}

void u_prog_b(void) {
    char* name = "prog_b";
    printf(" I am %s, my pid:%d%c", name, getpid(), '\n');
    while (1) {
    }
}