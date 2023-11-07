%include "boot.inc"

section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR


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


; 定义选择子
SELECTOR_CODE equ (0x0001 << 3) + TI_GDT + RPL0
SELECTOR_DATA equ (0x0002 << 3) + TI_GDT + RPL0
SELECTOR_VIDEO equ (0X0003 << 3) + TI_GDT + RPL0

; 当前偏移loader.bin文件头时0x200字节
; loader.bin的加载地址是0x900
; 故total_mem_bytes内存中的地址是0xb00
; 在内核中会引用此地址
total_mem_bytes dd 0

; 定义GDT的指针，前2字节时GDT界限，后4字节时GDT起始地址
gdt_ptr dw GDT_LIMIT 
        dd GDT_BASE

; 人工对齐: total_mem_bytes4+gdt_ptr6+ards_buf244+ards_nr2, 共256字节
ards_buf times 244 db 0
ards_nr dw 0    ; 用于记录ARDS结构体的数量

loader_start:
    ; --------int 15h eax = 0000E820h edx = 534D4150h ('SMAP') 获取内存布局 --------------
    xor ebx, ebx                ; 第一次调用时ebx要为0
    mov edx, 0x534d4150         ; edx只赋值一次，固定为签名
    mov di, ards_buf            ; ARDS结构缓冲区
    
    .e820_mem_get_loop:         ; 循环获取每个ARDS内存范围描述结构
        mov eax, 0x0000e820     ; 执行int 0x15后, eax值变为0x534d4150
        ; 所以每次执行int前都要更新为自功能号
        mov ecx, 20             ; ARDS地址范围描述符结构大小是20字节
        int 0x15
        jc .e820_failed_so_try_e801
        add di, cx              ; 使di增加20字节后指向缓冲区中新的ARDS结构位置
        inc word [ards_nr]      ; 记录ARDS数量
        cmp ebx, 0              ; 若ebx为0且cf不为1， 说明ARDS全部返回
        jnz .e820_mem_get_loop  ; ebx不为0，继续循环
        ; 在所有ARDS结构中
        ; 找出(base_add_low + length_low) 的最大值， 即内存的容量
        mov cx, [ards_nr]
        ; 遍历所有ARDS结构体
        mov ebx, ards_buf
        xor edx, edx            ; edx为最大的内存容量，先清0
    
    .find_max_mem_area:
        ; 无需判断type是否为1(可以被操作系统使用), 最大的内存块一定是可被使用的
        mov eax, [ebx]          ; base_add_low
        add eax, [ebx + 8]      ; eax = base_add_low + length_low
        add ebx, 20             ; 指向缓冲区下一个ARDS结构
        cmp edx, eax            
        jge .next_ards          ; edx >= eax
        mov edx, eax            ; edx为总内存大小，同时放最大内存
        .next_ards:
            loop .find_max_mem_area
            jmp .mem_get_ok


    ; --------int 15h ax = E801h 获取内存大小 最大支持4G --------------
    ; 返回后，ax和cx一样，以1KB为单位，bx和dx一样，以64KB为单位
    ; 在ax和cx寄存器中为低16MB，在bx和dx中为16MB到4GB
    .e820_failed_so_try_e801:
        mov ax, 0xe801
        int 0x15
        jc .e820_failed_so_try88

    ; 先算出低15MB的内存
    ; ax和cx中是以KB为单位的内存数量，先转换为byte为单位
    mov cx, 0x400     
    mul cx
    shl edx, 16
    and eax, 0x0000FFFF
    or edx, eax
    add edx, 0x100000           ; ax只是15MB，要加1MB 
    mov esi, edx                ; 先把低15MB的 内存容量存入esi寄存器备份
    ; 再将16MB以上的内存转换为byte为单位
    xor eax, eax
    mov ax, bx
    mov ecx, 0x10000            ; 0x10000 十进制 64K
    mul ecx                     ; 32位乘法，默认的被乘数是eax, 积为64位
                                ; 高32位存入edx，低32位存入eax
    add esi, eax
    mov edx, esi                ; edx 肯定为0
    jmp .mem_get_ok

    ; --------int 15h ax = 0x88h 获取内存大小 只能获取64MB之内 --------------
    .e820_failed_so_try88:
        ; int 15h之后，ax存入的是以KB为单位的内存容量
        mov ah, 0x88
        int 0x15
        jc .error_hlt
        and eax, 0x0000FFFF

        ; 16位乘法，被乘数是ax，积为32位。积的高16位在dx中，低16位在ax中
        mov cx, 0x400
        mul cx
        shl edx, 16
        or edx, eax
        add edx, 0x100000       ; 0x88子功能只会返回1MB以上的内存
                                ; 故实际内存大小要加1MB
    
    .error_hlt:
        jmp $
    .mem_get_ok:
        mov [total_mem_bytes], edx


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
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax
    mov byte [gs:160], 'P'       ; 默认文本显示模式是80×25，每个字符两个字节，因此偏移地址为80×2 = 160

; 加载kernel
mov eax, KERNEL_START_SECTOR 
mov ebx, KERNEL_BIN_BASE_ADDR
mov ecx, 200    
call rd_disk_m_32

; 创建页目录及页表并初始化页内存位图
call setup_page
; 要将描述符表地址及偏移量写入内存gdt_ptr, 一会儿用新地址重新加载
sgdt [gdt_ptr]                   ; 存储到原来gdt所有的位置
; 将gdt描述符中视频段描述符中的段基址+0xc0000000
mov ebx, [gdt_ptr + 2]
or dword [ebx + 0x18 + 4], 0xc0000000
; 视频段是第三个段描述符，每个描述符是8字节，故0x18
; 段描述符的高4字节的最高位是段基址的第31~24位
; 将gdt的基址加上0xc0000000使其成为内核所在的高地址
add dword [gdt_ptr + 2], 0xc0000000
add esp, 0xc0000000              ; 将栈指针同样映射到内和地质
; 把页目录地址赋给cr3
mov eax, PAGE_DIR_TABLE_POS
mov cr3, eax
; 打开cr0的pg位
mov eax, cr0
or eax, 0x80000000
mov cr0, eax
; 在开启分页后,用gdt的新地址重新加载
lgdt [gdt_ptr]                   


; 由于在32位下, 不需要刷新流水线,但是以防万一加了刷新流水线
jmp SELECTOR_CODE:enter_kernel   ; 强制刷新流水线,更新GDT
enter_kernel:
    call kernel_init
    mov esp, 0xc009f000
    jmp KERNEL_ENTRY_POINT

; --------将kernel.bin中的segment拷贝到编译的地址-----------
kernel_init:
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    
    mov dx, [KERNEL_BIN_BASE_ADDR + 42]
    ; e_phentsize, 表示program header大小
    mov ebx, [KERNEL_BIN_BASE_ADDR + 28]
    ; e_phoff, 表示第一个program header在文件中的偏移量
    
    add ebx, KERNEL_BIN_BASE_ADDR
    mov cx, [KERNEL_BIN_BASE_ADDR + 44] 
    ; e_phnum, 表示有几个program header

    .each_segment:
        cmp byte [ebx + 0], PT_NULL
        ; 若p_type = PT_NULL, 则说明program header未使用
        je .PTNULL

        ; 为函数memcpy压入参数，参数是从右往左以此压入
        ; 函数原型类似与memcpy(dst, src, size)
        push dword [ebx + 16]
        ; program header 中偏移16字节的地方是p_filesz
        ; 压入memcpy 的第三个参数size

        mov eax, [ebx + 4]      ; 距program header偏移量为4字节的位置是p_offset 
        add eax, KERNEL_BIN_BASE_ADDR
        ; 加上kernel.bin被加载到的物理地址, eax为该段的物理地址

        push eax                ; 压入src
        push dword [ebx + 8]    ; 压入dst
        call mem_cpy
        add esp, 12             ; 清理栈中压入的三个参数
    
    .PTNULL:
        add ebx, edx            ; edx为program header大小，即e_phentsize
                                ; 在此ebx指向下一个program header
        loop .each_segment
        ret

; ------------逐字节拷贝mem_cpy(dst, src, size)-------------
mem_cpy:
    cld                         ; 控制eflags寄存器中的方向标位，将其置0
    push ebp
    mov ebp, esp                ; 构造栈帧
    push ecx                    ; rep指令用到了ecx
                                ; 但ecx对于外层段的循环还有用, 故先入栈备份
    mov edi, [ebp + 8]          ; dst
    mov esi, [ebp + 12]         ; src
    mov ecx, [ebp + 16]         ; size
    rep movsb                   ; 逐字节拷贝
    ; 恢复环境
    pop ecx
    pop ebp
    ret





; ------------创建页目录及页表-------------
setup_page:
; 先把页目录占用的空间逐字节清0
    mov ecx, 4096
    mov esi, 0
    
    .clear_page_dir:
        mov byte [PAGE_DIR_TABLE_POS + esi], 0
        inc esi
        loop .clear_page_dir
    
    ; 开始创建页目录项(PDE)
    .create_pde:
        mov eax, PAGE_DIR_TABLE_POS
        add eax, 0x1000         ; 此时eax是第一个页表的位置及属性, 0x101000
        mov ebx, eax            ; 为.create_pte作准备，ebx为基址

        ; 下面将页目录项0和0xc00都存位第一个也表的地址，每个页表表示4MB
        ; 这样0xc03fffff以下的地址和0x003fffff以下的地址都指向相同的页表
        or eax, PG_US_U | PG_RW_W | PG_P
        ; 页目录的属性RW和P位为1，US为1，表示用户属性，所有特权级别都可以访问
        mov [PAGE_DIR_TABLE_POS + 0x0], eax
        ; 在页目录表的第一个目录项写入第一个页表的位置(0x101000)及属性(7)
        mov [PAGE_DIR_TABLE_POS + 0xc00], eax
        ; 0xc00表示第768=1024/4*3个页表占用的目录项，0xc00以上的目录项用于内核空间
        ; 也就是页表的0xc0000000~0xffffffff共计1G属于内核
        ; 0x0~0xbfffffff共计3G属于用户进程
        sub eax, 0x1000
        mov [PAGE_DIR_TABLE_POS + 4092], eax
        ; 使最后一个目录项指向页目录表自己的地址

    ; 下面开始创建页表项(PTE)
        mov ecx, 256                        ;  1M低端内存 / 每页大小4K = 256
        mov esi, 0
        mov edx, PG_US_U | PG_RW_W | PG_P   ; 属性为7(111b)
    .create_pte:
        mov [ebx + esi * 4], edx
        ; 此时ebx在上面通过eax赋值为0x101000,也就是第一个页表的地址
        add edx, 4096
        inc esi
        loop .create_pte

    ; 创建内核其其他页表的PDE
        mov eax, PAGE_DIR_TABLE_POS
        add eax, 0x2000                     ; 第二个页表的位置
        or eax, PG_US_U | PG_RW_W | PG_P    
        mov ebx, PAGE_DIR_TABLE_POS
        mov ecx, 254                        ; 范围769~1022的所有目录项数量
        mov esi, 769
    .create_kernel_pde:
        mov [ebx + esi * 4], eax
        inc esi
        add eax, 0x1000
        loop .create_kernel_pde
    ret

; ---------------------------
; 功能：读取硬盘n个扇区
rd_disk_m_32:   ; 0xcf6
; ---------------------------
    mov esi, eax
    mov di, cx

    mov dx, 0x1f2
    mov al, cl 
    out dx, al
    mov eax, esi

    mov dx, 0x1f3
    out dx, al

    mov cl, 8
    shr eax, cl
    mov dx, 0x1f4
    out dx, al

    shr eax, cl
    mov dx, 0x1f5
    out dx, al

    shr eax, cl
    and al, 0x0f
    or al, 0xe0
    mov dx, 0x1f6
    out dx, al

; 向0x1f7端口写入读命令, 0x20
    mov dx, 0x1f7
    mov al, 0x20
    out dx, al

; 检测硬盘状态
    .not_ready:
        ; 同一端口，写时表示写入命令字，读时表示读如硬盘状态
        nop
        in al, dx
        and al, 0x88
        ; 第3位DRQ为1表示硬盘控制器已准备好数据传输
        ; 第7位BSY为1表示硬盘忙
        cmp al, 0x08
        jnz .not_ready  ; 没准备好就继续等

; 从0x1f0端口读数据
    mov ax, di
    mov dx, 256
    mul dx
    mov cx, ax
    ; di为要读取的扇区数，一个扇区512字节，每一读如一个字
    ; 共需di*512/2次，所以di*256

    mov dx, 0x1f0

    .go_on_read:
        in ax, dx
        mov [ebx], ax
        add ebx, 2
        loop .go_on_read
    ret