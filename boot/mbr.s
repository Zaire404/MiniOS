%include "boot.inc"
section MBR vstart=0x7c00
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00
    mov ax, 0xb800 ; 显卡 用文本模式显示适配器
    mov gs, ax
; 清屏
; AH 功能号 = 0x06   
; AL 上卷的行数 (0表示全部)
; BH 上卷行属性
; (CL,CH) 窗口左上角的位置
; (DL,DH) 窗口右下角的位置
    mov ax, 0x600
    mov bx, 0x700
    mov cx, 0        ; 左上角: (0,0)
    mov dx, 0x184f  ; 右下角: (0,0)
    int 0x10

; 打印字符串
    mov byte [gs:0x00], '1'
    mov byte [gs:0x01], 0xA4 

    mov byte [gs:0x02], ' ' 
    mov byte [gs:0x03], 0xA4 

    mov byte [gs:0x04], 'M' 
    mov byte [gs:0x05], 0xA4 

    mov byte [gs:0x06], 'B' 
    mov byte [gs:0x07], 0xA4 

    mov byte [gs:0x08], 'R'
    mov byte [gs:0x09], 0xA4 


    mov eax, LOADER_START_SECTOR    ; 起始扇区lba地址
    mov bx, LOADER_BASE_ADDR        ; 写入地址
    mov cx, 4                       ; 待读如的扇区数
    call rd_disk_m_16               ; 以下读取程序的起始部分(一个扇区)

    jmp LOADER_BASE_ADDR


; ---------------------------
; 功能：读取硬盘n个扇区
rd_disk_m_16:
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
        mov [bx], ax
        add bx, 2
        loop .go_on_read
    ret
    
    times 510-($-$$) db 0
    db 0x55, 0xaa
        