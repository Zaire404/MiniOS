#!/bin/bash
for file in *.s; do
  filename=$(basename -- "$file")
  filename_noext="${filename%.*}"
  
  nasm -I include/ -o "${filename_noext}.bin" "$file"
  
  echo "Compiled $file into ${filename_noext}.bin"
done

dd if=./mbr.bin of=/opt/bochs/hd60M.img bs=512 count=1 conv=notrunc

dd if=./loader.bin of=/opt/bochs/hd60M.img bs=512 count=4 seek=2 conv=notrunc