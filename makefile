BUILD_DIR = ./build
ENTRY_POINT = 0xc0001500
HD60M_PATH = /opt/bochs/hd60M.img
AS = nasm
CC = gcc
LD = ld
LIB = -I lib/ -I lib/kernel/ -I lib/user/ -I kernel/ -I device/ -I thread/
ASFLAGS = -f elf
CFLAGS = -m32 -Wall $(LIB) -c -fno-builtin -fno-stack-protector -W -Wstrict-prototypes -Wmissing-prototypes 
LDFLAGS = -m elf_i386 -Ttext $(ENTRY_POINT) -e main -Map $(BUILD_DIR)/kernel.map
OBJS =  $(BUILD_DIR)/main.o \
		$(BUILD_DIR)/init.o \
		$(BUILD_DIR)/kernel.o \
		$(BUILD_DIR)/print.o \
		$(BUILD_DIR)/interrupt.o \
		$(BUILD_DIR)/timer.o \
		$(BUILD_DIR)/debug.o \
		$(BUILD_DIR)/string.o \
		$(BUILD_DIR)/bitmap.o \
		$(BUILD_DIR)/memory.o \
		$(BUILD_DIR)/thread.o \
		$(BUILD_DIR)/list.o \
		$(BUILD_DIR)/switch.o

# Compile boot files
boot: $(BUILD_DIR)/mbr.o $(BUILD_DIR)/loader.o

$(BUILD_DIR)/mbr.o: boot/mbr.s
	$(AS) -I boot/include/ -o $@ $<

$(BUILD_DIR)/loader.o: boot/loader.s
	$(AS) -I boot/include/ -o $@ $<

# Compile C kernel files
$(BUILD_DIR)/%.o: kernel/%.c
	$(CC) $(CFLAGS) -o $@ $<

$(BUILD_DIR)/%.o: device/%.c
	$(CC) $(CFLAGS) -o $@ $<

$(BUILD_DIR)/%.o: lib/%.c
	$(CC) $(CFLAGS) -o $@ $<

$(BUILD_DIR)/%.o: lib/kernel/%.c
	$(CC) $(CFLAGS) -o $@ $<

$(BUILD_DIR)/%.o: thread/%.c
	$(CC) $(CFLAGS) -o $@ $<

# Compile assembly kernel files
$(BUILD_DIR)/%.o: kernel/%.s
	$(AS) $(ASFLAGS) -o $@ $<

$(BUILD_DIR)/%.o: lib/kernel/%.s
	$(AS) $(ASFLAGS) -o $@ $<

$(BUILD_DIR)/%.o: thread/%.s
	$(AS) $(ASFLAGS) -o $@ $<

# Link all kernel object files
$(BUILD_DIR)/kernel.bin: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $^

# Utility rules
.PHONY: mk_dir hd clean build all boot

# 判断build文件夹是否存在，如果不存在，则创建
mk_dir:
	if [ ! -d $(BUILD_DIR) ]; then mkdir $(BUILD_DIR); fi

hd:
	dd if=build/mbr.o of=$(HD60M_PATH) bs=512 count=1 conv=notrunc && \
	dd if=build/loader.o of=$(HD60M_PATH) bs=512 count=4 seek=2 conv=notrunc && \
	dd if=$(BUILD_DIR)/kernel.bin of=$(HD60M_PATH) bs=512 count=200 seek=9 conv=notrunc

clean:
	@cd $(BUILD_DIR) && rm -f ./* && echo "All files in ./build removed"

build: $(BUILD_DIR)/kernel.bin

# make all 就是依次执行mk_dir build hd
all: mk_dir boot build hd