# Linux Initrd v0.5 详细构建教程

## 从零开始构建最小 Linux 系统

**文档版本**: 1.0  
**作者**: 璇璇子  
**日期**: 2025-04-13  
**目标读者**: Linux 初学者

---

## 📚 目录

1. [前言](#前言)
2. [基本概念](#基本概念)
3. [准备工作](#准备工作)
4. [详细构建步骤](#详细构建步骤)
5. [测试验证](#测试验证)
6. [故障排查](#故障排查)

---

## 前言

### 什么是 v0.5？

v0.5 是整个 Linux Initrd 项目的**起点**，它是一个**最简化的可启动 Linux 系统**，仅包含运行 shell 所需的最基本组件。

### 为什么要从 v0.5 开始？

| 学习目标 | 说明 |
|----------|------|
| 理解 initrd | 什么是 Initial RAM Disk，它如何工作 |
| 最小系统 | Linux 系统运行的最基本需求是什么 |
| 依赖关系 | 程序如何找到它们需要的库文件 |
| 启动流程 | 从开机到 shell 的完整过程 |

### v0.5 能做什么？

✅ 启动到 bash shell  
✅ 运行基本命令（ls, cat, echo 等）  
✅ 挂载 proc/sys/dev 文件系统  

---

## 基本概念

### 1. 什么是 Initrd？

**Initrd** = **Init**ial **R**am **D**isk（初始内存盘）

```
系统启动流程:
1. BIOS/UEFI 加载内核
2. 内核加载 initrd 到内存
3. 内核执行 initrd 中的 /init 脚本
4. /init 挂载必要的文件系统
5. 启动 shell
```

### 2. Linux 启动的最小需求

- **内核**: vmlinuz
- **initrd**: 包含基本程序和库
- **init 脚本**: 挂载文件系统并启动 shell

### 3. 动态链接库

**动态链接 vs 静态链接**:

```
静态链接: 程序包含所有代码 = 10MB
动态链接: 程序 + 运行时加载库 = 100KB + lib/
```

**查看依赖**: `ldd /bin/bash`

---

## 准备工作

### 系统要求

- **操作系统**: Ubuntu 22.04 LTS
- **架构**: x86_64
- **权限**: 普通用户

### 需要的工具

```bash
which ldd cpio gzip mkdir cp
```

### 创建工作目录

```bash
cd ~/linux_class
mkdir -p initrd0.5
```

---

## 详细构建步骤

### 步骤 1: 创建目录结构

```bash
cd ~/linux_class
mkdir -p initrd0.5/{bin,dev,etc,proc,sys,tmp,root,sbin,lib,lib64}
chmod 777 initrd0.5/tmp
```

**目录说明**:
- bin/: 基本命令
- lib/: 库文件
- proc/, sys/, dev/: 虚拟文件系统挂载点
- tmp/: 临时文件

### 步骤 2: 复制基础程序

```bash
cd ~/linux_class/initrd0.5

# 复制 bash
cp /bin/bash bin/
ln -s bash bin/sh

# 复制基本命令
for cmd in ls mkdir cat mount umount cp mv rm ps echo; do
    cp /bin/$cmd bin/
done
```

### 步骤 3: 复制依赖库

```bash
cd ~/linux_class/initrd0.5

# 为每个程序复制依赖
for prog in bin/*; do
    if [ -f "$prog" ] && [ ! -L "$prog" ]; then
        ldd "$prog" | grep -o '/lib[^[:space:]]*' | while read lib; do
            [ -f "$lib" ] && cp -n "$lib" lib/ 2>/dev/null || true
        done
    fi
done

# 复制动态链接器
cp /lib64/ld-linux-x86-64.so.2 lib64/
```

### 步骤 4: 创建 init 脚本

```bash
cd ~/linux_class/initrd0.5

cat > init << 'INNEREOF'
#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

echo "[v0.5] Mounting virtual filesystems..."
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

echo "Starting interactive shell..."
exec /bin/bash
INNEREOF

chmod +x init
```

**说明**:
- mount -t proc: 挂载进程信息文件系统
- mount -t sysfs: 挂载系统信息文件系统
- mount -t devtmpfs: 挂载设备文件系统
- exec /bin/bash: 启动 shell（替换当前进程）

### 步骤 5: 打包 initrd

```bash
cd ~/linux_class/initrd0.5

# cpio 打包 + gzip 压缩
find . | cpio -o -H newc | gzip -9 > ../initrd0.5.img

# 查看结果
ls -lh ../initrd0.5.img
```

**打包说明**:
- `find .`: 列出所有文件
- `cpio -o -H newc`: 创建 newc 格式归档
- `gzip -9`: 最大压缩

---

## 测试验证

### 启动命令

```bash
cd ~/linux_class
qemu-system-x86_64 \
    -kernel ./vmlinuz-6.8.0-90-generic \
    -initrd initrd0.5.img \
    -m 256 \
    -append "root=/dev/ram0 rw console=ttyS0,115200" \
    -nographic
```

### 预期输出

```
[v0.5] Mounting virtual filesystems...
Starting interactive shell...
bash-5.1#
```

### 测试命令

```bash
# 查看当前目录
pwd                    # /

# 列出根目录
ls -la /

# 查看挂载的文件系统
mount

# 查看内核版本
cat /proc/version

# 查看进程
ps
```

### 退出 QEMU

按 `Ctrl+A` 然后按 `X`

---

## 故障排查

| 问题 | 原因 | 解决 |
|------|------|------|
| cannot execute binary file | 架构不匹配 | file bin/bash 检查 |
| error while loading shared libraries | 缺少库 | ldd 检查并复制 |
| No working init found | init 无权限 | chmod +x init |
| mount failed | 目录不存在 | mkdir proc sys dev |

---

## 总结

### v0.5 关键要点

1. **目录结构** - bin/, lib/, proc/, sys/, dev/ 必需
2. **依赖库** - 使用 ldd 找出并复制
3. **动态链接器** - lib64/ld-linux-x86-64.so.2
4. **init 脚本** - 挂载文件系统并启动 shell
5. **打包格式** - cpio newc + gzip

### 下一步

继续学习 **v0.6** - 添加 udev 硬件检测！

---

**文档结束**
EOF