#include "dir.h"
#include "fs.h"
#include "init.h"
#include "interrupt.h"
#include "stdio.h"
#include "string.h"

int main(void) {
    init_all();
    intr_enable();
    char cwd_buf[32] = {0};
    sys_getcwd(cwd_buf, 32);
    printf("cwd:%s\n", cwd_buf);
    sys_chdir("/dir1");
    printf("change cwd now\n");
    sys_getcwd(cwd_buf, 32);
    printf("cwd:%s\n", cwd_buf);
    while (1) {
    };
    return 0;
}
