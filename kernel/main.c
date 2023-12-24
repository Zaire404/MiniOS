#include "dir.h"
#include "fs.h"
#include "init.h"
#include "interrupt.h"
#include "stdio.h"
#include "string.h"

int main(void) {
    init_all();
    intr_enable();
    struct dir *p_dir = sys_opendir("/dir1/subdir1");
    if (p_dir) {
        printf("/dir1/subdir1 open done!\ncontent:\n");
        char *type = NULL;
        struct dir_entry *dir_e = NULL;
        while ((dir_e = sys_readdir(p_dir))) {
            if (dir_e->f_type == FT_REGULAR) {
                type = "regular";
            } else {
                type = "directory";
            }
            printf("      %s   %s\n", type, dir_e->filename);
        }
        if (sys_closedir(p_dir) == 0) {
            printf("/dir1/subdir1 close done!\n");
        } else {
            printf("/dir1/subdir1 close fail!\n");
        }
    } else {
        printf("/dir1/subdir1 open fail!\n");
    }
    while (1) {
    };
    return 0;
}
