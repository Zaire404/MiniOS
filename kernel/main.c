#include "fs.h"
#include "init.h"
#include "interrupt.h"

int main(void) {
    init_all();
    intr_enable();
    sys_open("/file1", O_CREAT);
    while (1) {
    };
    return 0;
}
