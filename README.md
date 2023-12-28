# MiniOS
基于《操作系统真象还原》实现的操作系统

每一章完成后的代码在各自的branch
- 0x05 保护模式进阶，向内核迈进
- 0x06 完善内核
- 0x07 中断
- 0x08 内存管理系统
- 0x09 线程
- 0x0A 输入输出系统
- 0x0B 用户进程
- 0x0C 进一步完善内核
- 0x0D 编写硬盘驱动程序
- 0x0E 文件系统
- 0x0F 系统交互

## 运行说明

#### 下载
```
git clone https://github.com/Zaire404/MiniOS.git
cd MiniOS
```
#### 配置`bochsrc.disk`和`makefile`
修改配置文件中的bochs位置和硬盘位置
#### 编译装载
```
sudo make all
```
#### 运行
```
bochs -f bochsrc.disk
```




