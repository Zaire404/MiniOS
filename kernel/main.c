#include "fs.h"
#include "init.h"
#include "interrupt.h"
#include "stdio.h"

int main(void) {
    init_all();
    intr_enable();
    uint32_t fd = sys_open("/file1", O_RDONLY);
    printf("fd:%d\n", fd);
    sys_close(fd);
    printf("%d closed now\n", fd);
    while (1) {
    };
    return 0;
}
