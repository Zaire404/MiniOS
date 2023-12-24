#include "fs.h"
#include "init.h"
#include "interrupt.h"
#include "stdio.h"
#include "string.h"

int main(void) {
    init_all();
    intr_enable();
    uint32_t fd = sys_open("/file1", O_RDWR);
    printf("open /file1, fd:%d\n", fd);
    char buf[64] = {0};
    int read_bytes = sys_read(fd, buf, 18);
    printf("1_ read %d bytes:\n%s\n", read_bytes, buf);

    memset(buf, 0, 64);
    read_bytes = sys_read(fd, buf, 6);
    printf("2_ read %d bytes:\n%s", read_bytes, buf);

    memset(buf, 0, 64);
    read_bytes = sys_read(fd, buf, 6);
    printf("3_ read %d bytes:\n%s", read_bytes, buf);

    printf("________  SEEK SET 0  ________\n");
    sys_lseek(fd, 0, SEEK_SET);
    memset(buf, 0, 64);
    read_bytes = sys_read(fd, buf, 24);
    printf("4_ read %d bytes:\n%s", read_bytes, buf);

    sys_close(fd);
    while (1) {
    };
    return 0;
}
