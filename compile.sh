#!/bin/bash
for file in *.s; do
  filename=$(basename -- "$file")
  filename_noext="${filename%.*}"
  
  nasm -I include/ -o "${filename_noext}.bin" "$file"
  
  echo "Compiled $file into ${filename_noext}.bin"
done

dd if=./boot/mbr.bin of=/opt/bochs/hd60M.img bs=512 count=1 conv=notrunc

dd if=./boot/loader.bin of=/opt/bochs/hd60M.img bs=512 count=4 seek=2 conv=notrunc


gcc -m32 -o kernel/main.o -c kernel/main.c
ld -m elf_i386 kernel/main.o -T kernel/link.script -Ttext 0xc0001500 -e main -o kernel/kernel.bin
strip --remove-section=.note.gnu.property kernel/kernel.bin
dd if=./kernel/kernel.bin of=/opt/bochs/hd60M.img bs=512 count=20 seek=9 conv=notrunc