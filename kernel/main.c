#include "debug.h"
#include "init.h"
#include "interrupt.h"
#include "memory.h"
#include "print.h"
#include "thread.h"

void k_thread_a(void*);
void k_thread_b(void*);

int main(void) {
    init_all();
    thread_start("k_thread_a", 31, k_thread_a, "argA ");
    thread_start("k_thread_b", 8, k_thread_b, "argB ");
    intr_enable();
    put_str("\n");
    while (1) {
        intr_disable();
        put_str("Main ");
        intr_enable();
    };
    return 0;
}

void k_thread_a(void* arg) {
    char* para = arg;
    while (1) {
        intr_disable();
        put_str(para);
        intr_enable();
    }
}
void k_thread_b(void* arg) {
    char* para = arg;
    while (1) {
        intr_disable();
        put_str(para);
        intr_enable();
    }
}