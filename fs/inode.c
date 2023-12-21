#include "inode.h"

#include "debug.h"
#include "ide.h"
#include "interrupt.h"
#include "list.h"
#include "stdint.h"
#include "string.h"
#include "super_block.h"

// 用来存储inode位置
struct inode_position {
    bool two_sec;       // inode是否跨扇区
    uint32_t sec_lba;   // inode所在的扇区号
    uint32_t off_size;  // inode在扇区内的字节偏移量
};

// 获取inode所在的扇区和扇区内的偏移量
static void inode_locate(struct partition* part, uint32_t inode_no, struct inode_position* inode_pos) {
    // inode_table在硬盘上是连续的
    ASSERT(inode_no < 4096);
    uint32_t inode_table_lba = part->sb->inode_table_lba;

    uint32_t inode_size = sizeof(struct inode);
    uint32_t off_size = inode_no * inode_size;  // 第inode_no号I结点相对于inode_table_lba的字节偏移量
    uint32_t off_sec = off_size / 512;          // 第inode_no号I结点相对于inode_table_lba的扇区偏移量
    uint32_t off_size_in_sec = off_size % 512;  // 待查找的inode所在扇区中的起始地址

    // 判断此i结点是否跨越2个扇区
    uint32_t left_in_sec = 512 - off_size_in_sec;
    if (left_in_sec < inode_size) {
        inode_pos->two_sec = true;
    } else {
        inode_pos->two_sec = false;
    }
    inode_pos->sec_lba = inode_table_lba + off_sec;
    inode_pos->off_size = off_size_in_sec;
}

// 将inode写入到分区part
void inode_sync(struct partition* part, struct inode* inode, void* io_buf) {
    uint8_t inode_no = inode->i_no;
    struct inode_position inode_pos;
    inode_locate(part, inode_no, &inode_pos);

    ASSERT(inode_pos.sec_lba <= (part->start_lba + part->sec_cnt));

    // 硬盘中的inode中的成员inode_tag和i_open_cnts是不需要的
    struct inode pure_inode;
    memcpy(&pure_inode, inode, sizeof(struct inode));
    pure_inode.i_open_cnts = 0;
    pure_inode.write_deny = false;
    pure_inode.inode_tag.prev = pure_inode.inode_tag.next = NULL;

    char* inode_buf = (char*)io_buf;
    if (inode_pos.two_sec) {
        // 若是跨了两个扇区, 就要读出两个扇区再写入两个扇区
        ide_read(part->my_disk, inode_pos.sec_lba, inode_buf, 2);
        memcpy((inode_buf + inode_pos.off_size), &pure_inode, sizeof(struct inode));
        ide_write(part->my_disk, inode_pos.sec_lba, inode_buf, 2);
    } else {
        // 若只是一个扇区
        ide_read(part->my_disk, inode_pos.sec_lba, inode_buf, 1);
        memcpy((inode_buf + inode_pos.off_size), &pure_inode, sizeof(struct inode));
        ide_write(part->my_disk, inode_pos.sec_lba, inode_buf, 1);
    }
}

// 根据i结点号返回相应的i结点
struct inode* inode_open(struct partition* part, uint32_t inode_no) {
    // 先在已打开inode链表中找inode,此链表是为提速创建的缓冲区
    struct list_elem* elem = part->open_inodes.head.next;
    struct inode* inode_found;
    while (elem != &part->open_inodes.tail) {
        inode_found = elem2entry(struct inode, inode_tag, elem);
        if (inode_found->i_no == inode_no) {
            inode_found->i_open_cnts++;
            return inode_found;
        }
        elem = elem->next;
    }

    // 由于open_inodes链表中找不到,下面从硬盘上读入此inode并加入到此链表
    struct inode_position inode_pos;
    inode_locate(part, inode_no, &inode_pos);

    // 为使通过sys_malloc创建的新inode被所有任务共享,
    // 需要将inode置于内核空间,故需要临时
    // 将cur_pbc->pgdir置为NULL, 使新创建的inode位于内核区
    struct task_struct* cur = running_thread();
    uint32_t* cur_pagedir_bak = cur->pgdir;
    cur->pgdir = NULL;
    // 以上三行代码完成后下面分配的内存将位于内核区
    inode_found = (struct inode*)sys_malloc(sizeof(struct inode));
    // 恢复pgdir
    cur->pgdir = cur_pagedir_bak;

    char* inode_buf;
    if (inode_pos.two_sec) {
        inode_buf = (char*)sys_malloc(1024);
        // i结点表是被partition_format函数连续写入扇区的,所以下面可以连续读出来
        ide_read(part->my_disk, inode_pos.sec_lba, inode_buf, 2);
    } else {
        inode_buf = (char*)sys_malloc(512);
        ide_read(part->my_disk, inode_pos.sec_lba, inode_buf, 1);
    }
    memcpy(inode_found, inode_buf + inode_pos.off_size, sizeof(struct inode));

    // 因为一会很可能要用到此inode,故将其插入到队首便于提前检索到
    list_push(&part->open_inodes, &inode_found->inode_tag);
    inode_found->i_open_cnts = 1;

    sys_free(inode_buf);
    return inode_found;
}

// 关闭inode或减少inode的打开数
void inode_close(struct inode* inode) {
    // 若没有进程再打开此文件,将此inode去掉并释放空间
    enum intr_status old_status = intr_disable();
    if (--inode->i_open_cnts == 0) {
        list_remove(&inode->inode_tag);  // 将I结点从part->open_inodes中去掉
        // inode_open时为实现inode被所有进程共享,
        // 已经在sys_malloc为inode分配了内核空间,
        // 释放inode时也要确保释放的是内核内存池
        struct task_struct* cur = running_thread();
        uint32_t* cur_pagedir_bak = cur->pgdir;
        cur->pgdir = NULL;
        sys_free(inode);
        cur->pgdir = cur_pagedir_bak;
    }
    intr_set_status(old_status);
}

// 初始化new_inode
void inode_init(uint32_t inode_no, struct inode* new_inode) {
    new_inode->i_no = inode_no;
    new_inode->i_size = 0;
    new_inode->i_open_cnts = 0;
    new_inode->write_deny = false;

    // 初始化块索引数组i_sector
    uint8_t sec_idx = 0;
    while (sec_idx < 13) {
        new_inode->i_sectors[sec_idx] = 0;
        sec_idx++;
    }
}