#include "interrupt.h"

#include "global.h"
#include "io.h"
#include "print.h"
#include "stdint.h"

#define IDT_DESC_CNT 0x81  // 目前总共支持的中断数
#define PIC_M_CTRL 0x20    // 主片控制端口
#define PIC_M_DATA 0x21    // 主片数据端口
#define PIC_S_CTRL 0xA0    // 从片控制端口
#define PIC_S_DATA 0xA1    // 从片数据端口

#define EFLAGS_IF 0x00000200  // eflags寄存器的if为1
#define GET_EFLAGS(EFLAG_VAR) asm volatile("pushfl; popl %0" : "=g"(EFLAG_VAR))

extern uint32_t syscall_handler(void);

// 中断门描述符结构体
struct gate_desc {
    uint16_t func_offset_low_word;
    uint16_t selector;
    uint8_t dcount;
    uint8_t attribute;
    uint16_t func_offset_high_word;
};

// 静态函数声明
static void make_idt_desc(struct gate_desc* p_gdesc, uint8_t attr, intr_handler function);
static struct gate_desc idt[IDT_DESC_CNT];  // 本质上就是个中断门描述符数组

extern intr_handler intr_entry_table[IDT_DESC_CNT];  // 声明引用定义在kernel.s中的中断处理函数入口数组
char* intr_name[IDT_DESC_CNT];
intr_handler idt_table[IDT_DESC_CNT];

// 初始化可编程中断控制器
static void pic_init(void) {
    // 初始化主片
    outb(PIC_M_CTRL, 0x11);  // ICW1:边沿触发,级联8259,需要ICW4
    outb(PIC_M_DATA, 0x20);  // ICW2:起始中断向量号0x20,也就是IRQ0的中断向量号为0x20
    outb(PIC_M_DATA, 0x04);  // ICW3:设置IR2接从片
    outb(PIC_M_DATA, 0x01);  // ICW4:8086模式,正常EOI,非缓冲模式,手动结束中断

    // 初始化从片
    outb(PIC_S_CTRL, 0x11);  // ICW1:边沿触发,级联8259,需要ICW4
    outb(PIC_S_DATA, 0x28);  // ICW2:起始中断向量号0x28
    outb(PIC_S_DATA, 0x02);  // ICW3:设置从片连接到主片的IR2引脚
    outb(PIC_S_DATA, 0x01);  // ICW4:同上

    // 测试键盘, 只打开键盘中断, 其他全部关闭
    // outb(PIC_M_DATA, 0xfc);
    // outb(PIC_S_DATA, 0xff);
    outb(PIC_M_DATA, 0xf8);  // IRQ2用于级联从片,必须打开,否则无法响应从片上的中断主片上打开的中断有IRQ0的时钟,IRQ1的键盘和级联从片的IRQ2,其它全部关闭
    outb(PIC_S_DATA, 0xbf);  //打开从片上的IRQ14,此引脚接收硬盘控制器的中断

    put_str("pic init done!\n");
}

// 创建中断门描述符
static void make_idt_desc(struct gate_desc* p_gdesc, uint8_t attr, intr_handler function) {
    p_gdesc->func_offset_low_word = (uint32_t)function & 0x0000FFFF;
    p_gdesc->selector = SELECTOR_K_CODE;
    p_gdesc->dcount = 0;
    p_gdesc->attribute = attr;
    p_gdesc->func_offset_high_word = ((uint32_t)function & 0xFFFF0000) >> 16;
}

// 初始化中断描述表
static void idt_desc_init(void) {
    int last_index = IDT_DESC_CNT - 1;
    for (int i = 0; i < IDT_DESC_CNT; ++i) {
        make_idt_desc(&idt[i], IDT_DESC_ATTR_DPL0, intr_entry_table[i]);
    }
    // 单独处理系统调用, 系统调用对应的中断门dpl为3, 中断处理程序为单独的syscall_handler
    make_idt_desc(&idt[last_index], IDT_DESC_ATTR_DPL3, syscall_handler);
    put_str("idt desc init done");
}

// 通用中断处理函数
static void general_intr_handler(uint8_t vec_nr) {
    if (vec_nr == 0x27 || vec_nr == 0x2f) {
        // IRQ7和IRQ15会产生伪中断(spurious interrupt), 无需 处理
        // 0x2f是从片8259A上的最后一个IRQ引脚,保留项
        return;
    }
    // 将光标置为0, 从屏幕左上角清出一片打印异常信息的区域, 方便阅读
    set_cursor(0);  // 这里是print.s中的设置光标函数, 光标值范围是0～1999, 25*80
    int cursor_pos = 0;
    while (cursor_pos < 320) {
        put_char(' ');
        cursor_pos++;
    }
    set_cursor(0);  // 重置光标值
    put_str("!!!!!!!   exception message begin   !!!!!!!\n");
    set_cursor(88);  // 从第二行第8个字符开始打印
    put_str(intr_name[vec_nr]);
    if (vec_nr == 14) {  // 若为PageFault,将缺失的地址打印出来并悬停
        int page_fault_vaddr = 0;
        asm("movl %%cr2, %0" : "=r"(page_fault_vaddr));  // cr2存放造成PageFault的地址
        put_str("\npage fault addr is ");
        put_int(page_fault_vaddr);
    }
    put_str("\n!!!!!!!   exception message end   !!!!!!!");
    // 能进入中断处理程序就表示已经在关中断情况下了, 不会出现调度进程的情况, 因此下面的死循环不会被中断
    while (1) {
    };
}

// 完成一般中断处理函数注册以及异常名称注册
static void exception_init(void) {
    for (int i = 0; i < IDT_DESC_CNT; ++i) {
        // idt_table数组中的函数是进入中断后根据中断向量号调用的
        idt_table[i] = general_intr_handler;
        intr_name[i] = "unknown";
    }
    intr_name[0] = "#DE Divide Error";
    intr_name[1] = "#DB Debug Exception";
    intr_name[2] = "NMI Interrupt";
    intr_name[3] = "#BP Breakpoint Exception";
    intr_name[4] = "#OF Overflow Exception";
    intr_name[5] = "#BR BOUND Range Exceeded Exception";
    intr_name[6] = "#UD Invalid Opcode Exception";
    intr_name[7] = "#NM Device Not Available Exception";
    intr_name[8] = "#DF Double Fault Exception";
    intr_name[9] = "Coprocessor Segment Overrun";
    intr_name[10] = "#TS Invalid TSS Exception";
    intr_name[11] = "#NP Segment Not Present";
    intr_name[12] = "#SS Stack Fault Exception";
    intr_name[13] = "#GP General Protection Exception";
    intr_name[14] = "#PF Page-Fault Exception";
    // intr_name[15]是保留项，未使用
    intr_name[16] = "#MF x87 FPU Floating-Point Error";
    intr_name[17] = "#AC Alignment Check Exception";
    intr_name[18] = "#MC Machine-Check Exception";
    intr_name[19] = "#XF SIMD Floating-Point Exception";
}

// 开中断并返回中断前的状态
enum intr_status intr_enable() {
    enum intr_status old_status;
    if (INTR_ON == intr_get_status()) {
        old_status = INTR_ON;
    } else {
        old_status = INTR_OFF;
        asm volatile("sti");
    }
    return old_status;
}

enum intr_status intr_disable() {
    enum intr_status old_status;
    if (INTR_ON == intr_get_status()) {
        old_status = INTR_ON;
        asm volatile("cli" : : : "memory");
    } else {
        old_status = INTR_OFF;
    }
    return old_status;
}

// 在中断处理程序数组第vector_no个元素中注册安装中断处理程序function
void register_handler(uint8_t vector_no, intr_handler function) {
    // idt_table数组中的函数是在进入中断后根据中断向量号调用的
    idt_table[vector_no] = function;
}

// 将中断状态设置为status
enum intr_status intr_set_status(enum intr_status status) { return status & INTR_ON ? intr_enable() : intr_disable(); }

// 获取中断状态
enum intr_status intr_get_status() {
    uint32_t eflags = 0;
    GET_EFLAGS(eflags);
    return (EFLAGS_IF & eflags) ? INTR_ON : INTR_OFF;
}

// 完成有关中断的所有初始化工作
void idt_init() {
    put_str("idt_init start\n");
    idt_desc_init();
    exception_init();
    pic_init();

    uint64_t idt_operand = ((sizeof(idt) - 1) | ((uint64_t)(uint32_t)idt << 16));
    // 这里(sizeof(idt)-1)是表示段界限，占16位，然后我们的idt地址左移16位表示高32位，表示idt首地址
    asm volatile("lidt %0" : : "m"(idt_operand));
    put_str("idt_init done\n");
}