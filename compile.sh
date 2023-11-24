#!/bin/bash
echo "------------- boot ---------------"
for file in boot/*.s; do
  filename=$(basename -- "$file")
  filename_noext="${filename%.*}"
  
  nasm -I boot/include/ -o "build/${filename_noext}.bin" "$file"
  
  echo "Compiled $file into build/${filename_noext}.bin"
done

echo "\n------------------------------\n"

gcc -no-pie -fno-pic -m32 -I ./lib/kernel/ -c kernel/main.c -o build/main.o -fno-stack-protector
nasm -f elf -o build/print.o lib/kernel/print.s
nasm -f elf -o build/kernel.o kernel/kernel.s
gcc -I lib/kernel/ -I lib/ -I kernel/ -c -fno-builtin -o build/interrput.o -m32 kernel/interrupt.c -fno-stack-protector
gcc -m32 -I lib/kernel/ -I lib/ -I kernel/ -I device/ -c -fno-builtin -o build/init.o kernel/init.c -fno-stack-protector
gcc -m32 -I lib/kernel/ -I lib/ -I kernel/ -I device/ -c -fno-builtin -o build/timer.o device/timer.c -fno-stack-protector

echo "\n-------------link-------------\n"

ld -m elf_i386 -Ttext 0x00001500 -e main -o build/kernel.bin  build/main.o build/kernel.o build/init.o build/interrput.o build/print.o build/timer.o


echo "\n------------------------------\n"

dd if=./build/mbr.bin of=/opt/bochs/hd60M.img bs=512 count=1 conv=notrunc
dd if=./build/loader.bin of=/opt/bochs/hd60M.img bs=512 count=4 seek=2 conv=notrunc
dd if=./build/kernel.bin of=/opt/bochs/hd60M.img bs=512 count=200 seek=9 conv=notrunc