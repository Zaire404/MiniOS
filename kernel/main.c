#include "console.h"
#include "debug.h"
#include "init.h"
#include "interrupt.h"
#include "ioqueue.h"
#include "keyboard.h"
#include "memory.h"
#include "thread.h"
#include "process.h"

void k_thread_a(void*);
void k_thread_b(void*);
void u_prog_a(void);
void u_prog_b(void);
int test_var_a = 0, test_var_b = 0;

int main(void) {
    init_all();
    thread_start("consumer_a", 31, k_thread_a, "argA ");
    thread_start("consumer_b", 31, k_thread_b, "argB ");
    process_execute(u_prog_a, "user_prog_a");
    process_execute(u_prog_b, "user_prog_b");
    intr_enable();
    console_put_str("\n");
    while (1) {
    };
    return 0;
}

void k_thread_a(void* arg) {
    char* para = arg;
    while (1) {
        console_put_str("v_a:0x");
        console_put_int(test_var_a);
    }
}
void k_thread_b(void* arg) {
    char* para = arg;
    while (1) {
        console_put_str(" v_b:0x");
        console_put_int(test_var_b);
    }
}

void u_prog_a(void) {
    while (1) {
        test_var_a++;
    }
}

void u_prog_b(void) {
    while (1) {
        test_var_b++;
    }
}