[bits 32]
%define ERROR_CODE nop              ; 若在相关的异常中CPU已经自动压入了错误码, 为保持栈中格式统一, 这里不做操作
%define ZERO push 0                 ; 若在相关的异常中CPU没有压入错误码, 为了统一栈中格式,就手工压入一个0

extern put_str
extern idt_table

section .data
global intr_entry_table
intr_entry_table:
    %macro VECTOR 2                 ; 定义一个多行宏, 后面的2是指传递两个参数, 里面的%1, %2代表参数, 类似shell脚本
        section .text
        intr%1entry:                ; 每个中断处理程序都要压入中断向量号,所以一个中断类型一个中断处理程序,自己知道自己的向量号是多少
            %2                      ; 手工压入32位数据或者空操作,保证最后都会需要跨过一个4字节来iret
            push ds
            push es
            push fs
            push gs
            pushad

            ; 如果是从片上进入的中断，除了往从片上发送EOI外，还要往主片上发送EOI
            mov al, 0x20            ; 中断结束命令EOI
            out 0xa0, al            ; 向从片发送
            out 0x20, al            ; 向主片发送
            push %1                 ; 不管idt_table中的目标函数是否需要参数，一律压入中断向量号
            call [idt_table + %1*4] ; 调用idt_table中的C版本中断处理函数
            jmp intr_exit

        section .data
            dd intr%1entry          ; 存储各个中断入口程序的地址
                                    ; 形成intr_entry_table数组
                                    ; 因为编译后会将相同的section合并为一个段，所以会生成一个数组
    %endmacro

section .text
global intr_exit
intr_exit:
    ; 恢复上下文环境
    add esp, 4                      ; 跳过中断号
    popad
    pop gs
    pop fs
    pop es
    pop ds
    add esp, 4                      ; 跳过error_code或者说我们自己压入的0
    iretd

VECTOR 0x00,ZERO
VECTOR 0x01,ZERO
VECTOR 0x02,ZERO
VECTOR 0x03,ZERO
VECTOR 0x04,ZERO
VECTOR 0x05,ZERO
VECTOR 0x06,ZERO
VECTOR 0x07,ZERO
VECTOR 0x08,ZERO
VECTOR 0x09,ZERO
VECTOR 0x0a,ZERO
VECTOR 0x0b,ZERO
VECTOR 0x0c,ZERO
VECTOR 0x0d,ZERO
VECTOR 0x0e,ZERO
VECTOR 0x0f,ZERO
VECTOR 0x10,ZERO
VECTOR 0x11,ZERO
VECTOR 0x12,ZERO
VECTOR 0x13,ZERO
VECTOR 0x14,ZERO
VECTOR 0x15,ZERO
VECTOR 0x16,ZERO
VECTOR 0x17,ZERO
VECTOR 0x18,ZERO
VECTOR 0x19,ZERO
VECTOR 0x1a,ZERO
VECTOR 0x1b,ZERO
VECTOR 0x1c,ZERO
VECTOR 0x1d,ZERO
VECTOR 0x1e,ERROR_CODE
VECTOR 0x1f,ZERO
VECTOR 0x20,ZERO    ; 时钟中断对应的入口
VECTOR 0x21,ZERO    ; 键盘中断对应的入口
VECTOR 0x22,ZERO    ; 级联入口
VECTOR 0x23,ZERO    ; 串口2中断对应的入口  
VECTOR 0x24,ZERO    ; 串口1中断对应的入口
VECTOR 0x25,ZERO    ; 并口2中断对应的入口
VECTOR 0x26,ZERO    ; 软盘中断对应的入口
VECTOR 0x27,ZERO    ; 并口1中断对应的入口
VECTOR 0x28,ZERO    ; 实时钟中断对应的入口
VECTOR 0x29,ZERO    ; 重定向
VECTOR 0x2a,ZERO    ; 保留
VECTOR 0x2b,ZERO    ; 保留
VECTOR 0x2c,ZERO    ; ps/2鼠标
VECTOR 0x2d,ZERO    ; fpu浮点单元异常
VECTOR 0x2e,ZERO    ; 硬盘
VECTOR 0x2f,ZERO    ; 保留