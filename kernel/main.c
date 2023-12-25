#include "dir.h"
#include "fork.h"
#include "fs.h"
#include "init.h"
#include "interrupt.h"
#include "stdio.h"
#include "string.h"
#include "syscall.h"

void init(void);

int main(void) {
    init_all();
    while (1) {
    };
    return 0;
}

void init(void) {
    uint32_t ret_pid = fork();
    if (ret_pid) {
        printf("i am father, my pid is %d, child pid is %d\n", getpid(), ret_pid);
    } else {
        printf("i am child, my pid is %d, ret pid is %d\n", getpid(), ret_pid);
    }
    while (1) {
    };
}
