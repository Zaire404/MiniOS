#include "dir.h"
#include "fs.h"
#include "init.h"
#include "interrupt.h"
#include "stdio.h"
#include "string.h"

int main(void) {
    init_all();
    intr_enable();
    struct stat obj_stat;
    sys_stat("/", &obj_stat);
    printf("/`s info\n   i_no:%d\n   size:%d\n   filetype:%s\n", obj_stat.st_ino, obj_stat.st_size, obj_stat.st_filetype == 2 ? "directory" : "regular");
    sys_stat("/dir1", &obj_stat);
    printf("/dir1`s info\n   i_no:%d\n   size:%d\n   filetype:%s\n", obj_stat.st_ino, obj_stat.st_size, obj_stat.st_filetype == 2 ? "directory" : "regular");
    while (1) {
    };
    return 0;
}
