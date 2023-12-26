#include "assert.h"
#include "console.h"
#include "fork.h"
#include "ide.h"
#include "init.h"
#include "interrupt.h"
#include "print.h"
#include "shell.h"
#include "stdio-kernel.h"
#include "stdio.h"
#include "syscall.h"

void init(void);

int main(void) {
    init_all();
    intr_enable();
    uint32_t file_size = 4488;  //这个变量请自行修改成自己的prog_no_arg大小
    uint32_t sec_cnt = DIV_ROUND_UP(file_size, 512);
    struct disk *sda = &channels[0].devices[0];
    void *prog_buf = sys_malloc(file_size);
    ide_read(sda, 300, prog_buf, sec_cnt);
    int32_t fd = sys_open("/prog_no_arg", O_CREAT | O_RDWR);
    if (fd != -1) {
        if (sys_write(fd, prog_buf, file_size) == -1) {
            printk("file write error!\n");
            while (1) {
            }
        }
    }

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
    panic("init: should not be here");
}
