#include "init.h"

#include "console.h"
#include "interrupt.h"
#include "memory.h"
#include "print.h"
#include "thread.h"
#include "timer.h"
#include "keyboard.h"
#include "tss.h"

void init_all() {
    put_str("init_all\n");
    idt_init();
    timer_init();
    mem_init();
    thread_init();
    console_init();
    keyboard_init();
    tss_init();
}