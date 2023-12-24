#include "fs.h"
#include "init.h"
#include "interrupt.h"
#include "stdio.h"
#include "string.h"

int main(void) {
    init_all();
    intr_enable();
    printf("/file1 delete %s!\n", sys_unlink("/file1") == 0 ? "done" : "fail");
    while (1) {
    };
    return 0;
}
