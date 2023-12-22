#include "fs.h"
#include "init.h"
#include "interrupt.h"
#include "stdio.h"

int main(void) {
    init_all();
    intr_enable();
    uint32_t fd = sys_open("/file1", O_RDWR);
    printf("fd:%d\n", fd);
    sys_write(fd, "hello,world\n", 12);
    sys_close(fd);
    printf("%d closed now\n", fd);
    while (1) {
    };
    return 0;
}
