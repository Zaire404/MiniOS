TI_GDT equ 0
RPL0 equ 0
SELECTOR_VIDEO equ (0x0003 << 3) + TI_GDT + RPL0

[bits 32]
section .text
put_int_buffer dq 0


;------------------------put_str--------------------------
; 打印字符串
global put_str
put_str:
    push ebx
    push ecx
    xor ecx, ecx
    mov ebx, [esp + 12]
    .goon:
        mov cl, [ebx]
        cmp cl, 0
        jz .str_over
        push ecx
        call put_char
        add esp, 4
        inc ebx
        jmp .goon
    .str_over:
        pop ecx
        pop ebx
        ret 
       
;------------------------put_char--------------------------
; 把栈中的1个字符写入光标所在处
global put_char
put_char:
    pushad                      ; 备份32位寄存器环境
    ; 需要保证gs中为正确的视频段选择子
    ; 为保险起见，每次打印时都为gs赋值
    mov ax, SELECTOR_VIDEO      ; 不能直接把立即数送入段寄存器
    mov gs, ax      
    ;;;;;;获取当前光标位置;;;;;;
    ; 先获取高8位
    mov dx, 0x03d4              ; 索引寄存器
    mov al, 0x0e                ; 用于提供光标位置的高8位
    out dx, al
    mov dx, 0x03d5              ; 通过读写数据端口0x3d5来获得或设置光标位置
    in al, dx                   ; 得到光标位置的高8位
    mov ah, al

    ; 再获取低8位
    mov dx, 0x03d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x03d5
    in al, dx

    ; 将光标存入bx
    mov bx, ax
    ; 在栈中获取待打印的字符
    mov ecx, [esp + 36]         ; pushad压入4*8=32字节
                                ; 加上主调函数4字节的返回地址，故esp+36字节
    cmp cl, 0xd                 ; CR是0x0d回车符，这里在检查是否为不可打印字符
    jz .is_carriage_return 
    cmp cl, 0xa                 ; LF是0xa代表换行符
    jz .is_line_feed

    cmp cl, 0x8                 ; BS(backspace)的asc码是8
    jz .is_backspace
    jmp .put_other

    .is_backspace:
    ;;;;;;;;;;;;;backspace说明;;;;;;;;;;;;;;;;;
    ; 当为backspace时，本质上只要将光标移向前一个显存位置即可，后面再输入的字符自然会覆盖此处的字符
    ; 但有可能在键入backspace后并不再键入新的字符，这时光标已经向前移动到待删除的字符位置，但字符还在原处
    ; 所以此处添加了空格或空字符0
        dec bx                  
        shl bx, 1               ; 光标左移1位等于乘2
                                ; 表示光标对应显存的偏移字节
        mov byte [gs:bx], 0x20  ; 将待删除的字节补为0或空格皆可
        inc bx
        mov byte [gs:bx], 0x07  ; 黑屏白字
        shr bx, 1
        jmp .set_cursor
    
    .put_other:
        shl bx, 1
        mov [gs:bx], cl         ; ASCII字符本身
        inc bx
        mov byte [gs:bx], 0x07  ; 字符属性
        shr bx, 1               ; 恢复老的光标值
        inc bx
        cmp bx, 2000        
        jl .set_cursor          ; 若光标值小于2000，表示未写道
                                ; 显存的最后则去设置新的光标值
                                ; 若超出屏幕字符数大小(2000)
                                ; 则换行处理
    .is_line_feed:              ; 是换行符LF(\n)
    .is_carriage_return:        ; 是回车符CR(\r)
    ; 如果是CR，只要把光标移到行首就行
        xor dx, dx              ; dx是被除数的高16位，请0
        mov ax, bx              ; ax是被出书的低16位
        mov si, 80              ; 由于是效仿linux，linux中\n表示下一行行首
                                ; 所以本系统\n和\r都处理为linux的\n
        div si      
        sub bx, dx              ; 光标值减去除以80的余数便是取整，dx存放余数

    .is_carriage_return_end:
        add bx, 80              ; 换行+80
        cmp bx, 2000

    .is_line_feed_end:
        jl .set_cursor

    ; 屏幕行范围是0~24，滚屏的原理是将屏幕的第1~24行搬运到第0~23行
    ; 再将第24行用空格填充
    .roll_screen:               ; 若超出屏幕大小，开始滚屏
        cld
        mov ecx, 960            ; 2000-80=1920个字符要搬运，共1920*2=3840字节
                                ; 一次搬4字节，共3840/4=960次
        mov esi, 0xc00b80a0     ; 第1行行首
        mov edi, 0xc00b8000     ; 第0行行首
        rep movsd

        ; 将最或一行填充为空白
        mov ebx, 3840           ; 最后一行首字符的第一个字节偏移=1920*2
        mov ecx, 80             ; 一行80字符，每次清空1字符, 一行需要循环80次

    .cls:
        mov word [gs:ebx], 0x0720  ; 0x0720 黑屏白字 空格
        add ebx, 2             
        loop .cls
        mov bx, 1920            ; 将光标值重置为1920，最后一行的收字符
    
    .set_cursor:
    ; 将光标设置为bx值
    ; 先设置高8位
        mov dx, 0x03d4
        mov al, 0x0e
        out dx, al
        mov dx, 0x03d5
        mov al, bh
        out dx, al

        ; 再设置低8位
        mov dx, 0x03d4
        mov al, 0x0f
        out dx, al
        mov dx, 0x03d5
        mov al, bl
        out dx, al

    .put_char_done:
        popad
        ret


;------------------------put_int--------------------------
; 打印十六进制数字，并不打印0x
global put_int
put_int:
    pushad 
    mov ebp, esp
    mov eax, [ebp + 4 * 9]
    mov edx, eax
    mov edi, 7
    mov ecx, 8
    mov ebx, put_int_buffer
    
    .16based_4bits:
        and edx, 0x0000000F
        cmp edx, 9
        jg .is_A2F
        add edx, '0'
        jmp .store
    .is_A2F:
        sub edx, 10
        add edx, 'A'
    .store:
        mov [ebx + edi], dl
        dec edi
        shr eax, 4
        mov edx, eax
        loop .16based_4bits

    .ready_to_print:
        inc edi
    .skip_prefix_0:
        cmp edi, 8
        je .full0
    
    .go_on_skip:
        mov cl, [put_int_buffer + edi]
        inc edi
        cmp cl, '0'
        je .skip_prefix_0
        dec edi
        jmp .put_each_num
    
    .full0:
        mov cl, '0'
    .put_each_num:
        push ecx
        call put_char
        add esp, 4
        inc edi
        mov cl, [put_int_buffer + edi]
        cmp edi, 8
        jl .put_each_num
        popad
        ret