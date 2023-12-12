#ifndef __USERPROG_PROCESS_H
#define __USERPROG_PROCESS_H
#include "stdint.h"
#include "thread.h"

#define USER_STACK3_VADDR (0xc0000000 - 0x1000)
#define USER_VADDR_START 0x8048000
#define default_prio 31

void start_process(void* filename_);
void process_activate(struct task_struct* p_thread);
void page_dir_activate(struct task_struct* p_thread);
void process_execute(void* filename, char* name);
void create_user_vaddr_bitmap(struct task_struct* user_prog);
uint32_t* create_page_dir(void);
#endif
