#include "console.h"
#include "debug.h"
#include "fork.h"
#include "init.h"
#include "print.h"
#include "shell.h"
#include "stdio.h"
#include "syscall.h"

void init(void);

int main(void) {
    init_all();
    cls_screen();
    console_put_str("[root@localhost /]$ ");
    while (1) {
    }
    return 0;
}

void init(void) {
    uint32_t ret_pid = fork();
    if (ret_pid) {
        while (1) {
        }
    } else {
        my_shell();
    }
    PANIC("init: should not be here");
}
