#include "init.h"

#include "console.h"
#include "fs.h"
#include "ide.h"
#include "interrupt.h"
#include "keyboard.h"
#include "memory.h"
#include "print.h"
#include "syscall-init.h"
#include "thread.h"
#include "timer.h"
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
    syscall_init();
    intr_enable();    // 后面的ide_init需要打开中断
    ide_init();
    filesys_init();
}