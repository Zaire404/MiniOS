%include "boot.inc"

section loader vstart=LOADER_BASE_ADDR
LOADER_STACKP_TOP equ LOADER_BASE_ADDR
jmp loader_start 

; 构建GDT及其内部描述符
; GDT第0个是无效描述符
GDT_BASE: 
    dd 0x00000000
    dd 0x00000000

CODE_DESC: 
    dd 0x0000FFFF
    dd DESC_CODE_HIGH4

DATA_STACK_DESC:
    dd 0x0000FFFF
    dd DESC_DATA_HIGH4

VIDEO_DESC:
    dd 0x80000007       ; limit = (0xbffff - 0xb8000) / 4k = 0x7
                        ; 0xb8000~0xbffff是实模式下文本模式显存适配器的内存地址
    dd DESC_VIDEO_HIGH4

GDT_SIZE equ $ - GDT_BASE ; 计算当前GDT已经填充的大小
GDT_LIMIT equ GDT_SIZE - 1 ; GDT界限值，表示GDT大小
times 60 dq 0               ; 预留60各描述符空位

; 当前偏移loader.bin文件头时0x200字节
; loader.bin的加载地址是0x900
; 故total_mem_bytes内存中的地址是0xb00
; 在内核中会引用此地址
total_mem_bytes dd 0
; 定义选择子
SELECTOR_CODE equ (0x0001 << 3) + TI_GDT + RPL0
SELECTOR_DATA equ (0x0002 << 3) + TI_GDT + RPL0
SELECTOR_VIDEO equ (0X0003 << 3) + TI_GDT + RPL0

; 定义GDT的指针，前2字节时GDT界限，后4字节时GDT起始地址
gdt_ptr dw GDT_LIMIT 
        dd GDT_BASE
loadermsg db '2 loader in real.'

;----------------------------------------------
; INT 0x10   功能号：0x13    功能描述：打印字符串
;----------------------------------------------
; 输入：
; AH子功能号=13H
; BH = 页号
; BL = 属性
; CX = 字符串长度
; (DH,DL) = 字符串地址
; AL = 显示输出方式
;  0 -- 字符串只含显示字符，显示属性在BL中，显示后光标位置不变
;  1 -- 字符串只含显示字符，显示属性在BL中，显示后光标位置改变
;  2 -- 字符串只含显示字符和显示属性，显示后光标位置不变
;  3 -- 字符串只含显示字符和显示属性，显示后光标位置改变
;  无返回值
loader_start:
    mov sp, LOADER_BASE_ADDR
    mov bp, loadermsg       ; ES:BP = 字符串地址
    mov cx, 17              ; CS = 字符串长度
    mov ax, 0x1301          ; AH = 13H，AL = 01H
    mov bx, 0x001f          ; 页号为0，蓝底粉红字
    mov dx, 0x1800
    int 0x10

; 准备进入保护模式
; 1、打开A20
; 2、加载GDT
; 3、将CR0的PE位置1

; 打开A20,即将端口0x92第一位设置为1
in al, 0x92
or al, 0000_0010B
out 0x92, al

; 加载GDT
lgdt [gdt_ptr]

; CR0第0位置1，PE段开启保护模式
mov eax, cr0
or eax, 0x00000001
mov cr0, eax
jmp dword SELECTOR_CODE:p_mode_start   ; 刷新流水线

[bits 32] 
p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACKP_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax
    mov byte [gs:160], 'P'       ; 默认文本显示模式是80×25，每个字符两个字节，因此偏移地址为80×2 = 160

    jmp $


