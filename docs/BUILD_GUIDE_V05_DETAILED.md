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
5. [原理解析](#原理解析)
6. [测试验证](#测试验证)
7. [故障排查](#故障排查)
8. [扩展阅读](#扩展阅读)

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
✅ 理解 Linux 启动流程  

### 不能做什么？

❌ 自动检测硬件（需要 udev）  
❌ 用户认证（直接以 root 进入）  
❌ 网络功能  
❌ 服务管理  

---

## 基本概念

### 1. 什么是 Initrd？

**Initrd** = **Init**ial **R**am **D**isk（初始内存盘）

```
┌─────────────────────────────────────────────────────────────┐
│                     系统启动流程                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. BIOS/UEFI 加载内核 (vmlinuz)                            │
│                      ↓                                      │
│  2. 内核加载 initrd 到内存                                  │
│                      ↓                                      │
│  3. 内核执行 initrd 中的 /init 脚本                         │
│                      ↓                                      │
│  4. /init 挂载必要的文件系统                                │
│                      ↓                                      │
│  5. 启动 shell 或 systemd                                   │
│                      ↓                                      │
│  6. 用户登录                                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**为什么需要 initrd？**

1. **驱动问题**: 内核启动时需要驱动来访问根文件系统，但驱动可能在根文件系统上
2. **灵活性**: 可以在启动时执行脚本，处理硬件检测等
3. **救援模式**: 即使根文件系统损坏，也能进入 initrd 修复

### 2. Linux 启动的最小需求

一个能运行的 Linux 系统至少需要：

```
┌─────────────────────────────────────────────────────────────┐
│                    最小 Linux 系统                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  必需的文件系统:                                            │
│    ├── /proc  (进程信息)                                    │
│    ├── /sys   (系统信息)                                    │
│    └── /dev   (设备文件)                                    │
│                                                             │
│  必需的程序:                                                │
│    ├── /bin/bash (或其他 shell)                             │
│    ├── /bin/sh   (符号链接到 bash)                          │
│    └── /init     (启动脚本)                                 │
│                                                             │
│  必需的库:                                                  │
│    ├── libc.so.6    (C 标准库)                              │
│    ├── libdl.so.2   (动态加载)                              │
│    └── ...                                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3. 动态链接库

#### 什么是动态链接？

**静态链接**: 程序包含所有代码
```
程序 = 业务代码 + 库代码
     = 10KB + 1000KB
     = 1010KB
```

**动态链接**: 程序运行时加载库
```
程序 = 业务代码 + 库引用
     = 10KB + (运行时加载 libc.so)
     = 10KB
```

#### 如何查看依赖？

```bash
# 使用 ldd 查看程序依赖
ldd /bin/bash

# 输出示例:
# linux-vdso.so.1 => ...
# libtinfo.so.6 => /lib/x86_64-linux-gnu/libtinfo.so.6
# libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
# /lib64/ld-linux-x86-64.so.2
```

#### ldd 工作原理

```
ldd /bin/bash
    │
    ├── 读取 ELF 文件的 .dynamic 段
    │
    ├── 找到 NEEDED 条目 (需要的库)
    │   ├── libtinfo.so.6
    │   └── libc.so.6
    │
    ├── 按以下顺序查找库:
    │   1. LD_LIBRARY_PATH 环境变量
    │   2. /etc/ld.so.cache
    │   3. /lib, /usr/lib
    │
    └── 输出库的路径
```

### 4. initrd 的打包格式

initrd 使用 **cpio + gzip** 格式：

```
initrd.img
    │
    ├── gzip 压缩层 (gzip -9)
    │       │
    │       └── 解压后得到 cpio 归档
    │               │
    │               └── cpio 展开得到文件系统
    │                       │
    │                       ├── bin/
    │                       ├── lib/
    │                       ├── init
    │                       └── ...
```

**为什么选择 cpio？**
- 比 tar 更简单，适合 initramfs
- 内核原生支持
- 可以包含设备文件（需要 root 权限）

---

## 准备工作

### 系统要求

- **操作系统**: Ubuntu 22.04 LTS
- **内核**: 6.8.0-90-generic
- **架构**: x86_64
- **权限**: 普通用户（不需要 root）

### 需要的工具

```bash
# 检查工具是否安装
which ldd      # 查看程序依赖
which cpio     # 打包工具
which gzip     # 压缩工具
which mkdir    # 创建目录
which cp       # 复制文件
```

如果缺少工具：
```bash
sudo apt-get update
sudo apt-get install -y cpio gzip coreutils
```

### 创建工作目录

```bash
# 进入项目目录
cd ~/linux_class

# 创建工作目录
mkdir -p initrd0.5
```

---

## 详细构建步骤

### 步骤 1: 创建目录结构

**目标**: 创建 initrd 所需的目录

**命令**:
```bash
cd ~/linux_class
mkdir -p initrd0.5/{bin,dev,etc,proc,sys,tmp,root,sbin,lib,lib64}
```

**创建的目录**:
```
initrd0.5/
├── bin/      # 基本命令
├── dev/      # 设备文件（空，由 devtmpfs 填充）
├── etc/      # 配置文件
├── proc/     # proc 文件系统挂载点
├── sys/      # sysfs 文件系统挂载点
├── tmp/      # 临时文件
├── root/     # root 用户家目录
├── sbin/     # 系统命令
├── lib/      # 32位库文件
└── lib64/    # 64位库文件
```

**原理解析**:

| 目录 | 作用 | 是否必需 |
|------|------|----------|
| bin/ | 普通用户命令 | 是 |
| sbin/ | 系统管理员命令 | 否 |
| dev/ | 设备文件 | 是（可空，由 devtmpfs 填充） |
| proc/ | 进程信息 | 是 |
| sys/ | 系统信息 | 是 |
| tmp/ | 临时文件 | 是 |
| root/ | root 家目录 | 是 |
| lib/ | 库文件 | 是 |
| lib64/ | 64位库 | 是（x86_64） |
| etc/ | 配置文件 | 否（v0.5 不需要） |

**权限设置**:
```bash
# tmp 目录需要特殊权限
chmod 777 initrd0.5/tmp
```

---

### 步骤 2: 复制基础程序

**目标**: 复制 shell 和基本命令

#### 2.1 复制 bash 和 sh

**命令**:
```bash
cd ~/linux_class/initrd0.5

# 复制 bash
cp /bin/bash bin/

# 创建 sh 符号链接（指向 bash）
ln -s bash bin/sh
```

**为什么需要 sh？**
- 很多脚本使用 `#!/bin/sh` 作为解释器
- `/bin/sh` 是 POSIX 标准 shell
- 现代系统通常是 bash 的符号链接

#### 2.2 复制基本命令

**命令**:
```bash
cd ~/linux_class/initrd0.5

# 复制基本命令
for cmd in ls mkdir cat mount umount cp mv rm ps echo; do
    cp /bin/$cmd bin/
done
```

**命令功能**:

| 命令 | 功能 |
|------|------|
| ls | 列出目录内容 |
| mkdir | 创建目录 |
| cat | 查看文件内容 |
| mount | 挂载文件系统 |
| umount | 卸载文件系统 |
| cp | 复制文件 |
| mv | 移动/重命名文件 |
| rm | 删除文件 |
| ps | 查看进程 |
| echo | 输出文本 |

---

### 步骤 3: 复制依赖库

**目标**: 使用 ldd 自动复制所有依赖库

#### 3.1 复制单个程序的依赖

以 bash 为例：

**命令**:
```bash
cd ~/linux_class/initrd0.5

# 查看 bash 依赖
ldd /bin/bash
```

**输出示例**:
```
linux-vdso.so.1 (0x00007fff...)  [虚拟库，不需要复制]
libtinfo.so.6 => /lib/x86_64-linux-gnu/libtinfo.so.6
libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
/lib64/ld-linux-x86-64.so.2
```

**复制依赖**:
```bash
cd ~/linux_class/initrd0.5

# 复制 bash 的依赖
ldd /bin/bash | grep -o '/lib[^[:space:]]*' | while read lib; do
    if [ -f "$lib" ]; then
        cp "$lib" lib/
    fi
done
```

#### 3.2 批量复制所有命令的依赖

**命令**:
```bash
cd ~/linux_class/initrd0.5

# 为 bin/ 中的所有程序复制依赖
for prog in bin/*; do
    if [ -f "$prog" ] && [ ! -L "$prog" ]; then
        echo "Processing: $prog"
        ldd "$prog" | grep -o '/lib[^[:space:]]*' | while read lib; do
            if [ -f "$lib" ]; then
                cp -n "$lib" lib/ 2>/dev/null || true
            fi
        done
    fi
done
```

**原理解析**:

```
ldd /bin/ls
    │
    ├── 输出: /lib/x86_64-linux-gnu/libc.so.6
    │
    └── grep -o '/lib[^[:space:]]*'
            │
            └── 提取: /lib/x86_64-linux-gnu/libc.so.6
                    │
                    └── cp 到 lib/ 目录
```

#### 3.3 复制动态链接器

**命令**:
```bash
cd ~/linux_class/initrd0.5

# 复制 64 位动态链接器
cp /lib