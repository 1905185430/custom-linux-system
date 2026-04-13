# Linux Initrd v0.6 详细构建教程

## 添加 Udev 硬件检测支持

**文档版本**: 1.0  
**作者**: 璇璇子  
**日期**: 2025-04-13  
**前置版本**: v0.5  
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

### 什么是 v0.6？

v0.6 在 v0.5（最小系统）的基础上，添加了 **udev 硬件检测系统**。这是 Linux 系统能够自动识别和配置硬件设备的关键组件。

### 为什么需要 udev？

| 问题 | 说明 |
|------|------|
| 设备识别 | 内核如何知道有哪些硬件？ |
| 驱动加载 | 如何自动加载正确的驱动？ |
| 设备命名 | /dev/sda 是如何创建的？ |
| 热插拔 | USB 插入时发生了什么？ |

### v0.6 新增功能

✅ **udev 守护进程** - 自动检测硬件  
✅ **设备节点创建** - /dev/ 下的设备文件  
✅ **驱动模块加载** - 自动加载内核模块  
✅ **硬件信息查看** - lsmod, udevadm  

### 镜像大小变化

| 版本 | 大小 | 增长 | 主要原因 |
|------|------|------|----------|
| v0.5 | 4.2MB | - | 基础系统 |
| v0.6 | 45MB | +40.8MB | 内核驱动模块 |

---

## 基本概念

### 1. 什么是 udev？

**udev** = **U**ser-space **dev**ice management

```
┌─────────────────────────────────────────────────────────────┐
│                    Linux 设备管理架构                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  硬件设备 (键盘、鼠标、硬盘...)                              │
│         │                                                   │
│         ▼                                                   │
│  ┌───────────────┐                                          │
│  │  Linux 内核   │                                          │
│  │               │                                          │
│  │  ┌─────────┐  │  检测到新设备                            │
│  │  │ 驱动层  │  │        │                                 │
│  │  └────┬────┘  │        ▼                                 │
│  │       │       │  ┌───────────────┐                       │
│  │  ┌────┴────┐  │  │   uevent      │  发送事件到用户空间   │
│  │  │ uevent  │──┼──▶   机制        │                       │
│  │  └─────────┘  │  └───────┬───────┘                       │
│  └───────────────┘          │                               │
│                             ▼                               │
│  ┌─────────────────────────────────────┐                    │
│  │        用户空间 (user space)        │                    │
│  │                                     │                    │
│  │  ┌─────────────┐  ┌─────────────┐  │                    │
│  │  │ systemd-    │  │  udevadm    │  │                    │
│  │  │ udevd       │  │  (管理工具)  │  │                    │
│  │  └──────┬──────┘  └─────────────┘  │                    │
│  │         │                          │                    │
│  │         ▼                          │                    │
│  │  ┌─────────────┐                   │                    │
│  │  │  /dev/xxx   │  创建设备节点     │                    │
│  │  │  (设备文件) │                   │                    │
│  │  └─────────────┘                   │                    │
│  └─────────────────────────────────────┘                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2. udev 工作流程

```
1. 内核检测到新设备 (如插入 USB)
        │
        ▼
2. 内核生成 uevent 事件
   (包含设备信息：类型、ID、总线等)
        │
        ▼
3. 通过 netlink socket 发送给用户空间
        │
        ▼
4. systemd-udevd 接收事件
        │
        ▼
5. udevd 根据规则处理：
   ├── 加载驱动模块
   ├── 创建设备节点
   ├── 设置权限
   └── 触发其他动作
        │
        ▼
6. 设备可用！(/dev/xxx 已创建)
```

### 3. 关键组件

#### systemd-udevd

udev 的守护进程，负责：
- 监听内核事件
- 执行规则匹配
- 创建设备节点
- 加载驱动模块

#### udevadm

管理工具，用于：
- 手动触发设备扫描
- 查询设备信息
- 测试规则
- 监控事件

**常用命令**:
```bash
udevadm trigger --action=add    # 触发所有设备的 add 动作
udevadm settle                  # 等待所有事件处理完成
udevadm info --query=all /dev/sda  # 查询设备信息
```

### 4. 设备节点

#### 什么是设备节点？

```
/dev/ttyS0    ← 串口设备
/dev/sda      ← 硬盘设备  
/dev/null     ← 空设备
/dev/random   ← 随机数设备
```

设备节点是用户空间访问硬件的接口：
- **字符设备**: 顺序访问（串口、键盘）
- **块设备**: 随机访问（硬盘、分区）

#### 设备号

```bash
ls -la /dev/
# crw-r--r-- 1 root root 1, 3 Jan 1 00:00 null
#                   │   │
#                   │   └── 次设备号 (minor)
#                   └────── 主设备号 (major)
```

- **主设备号**: 标识驱动类型
- **次设备号**: 标识具体设备

---

## 准备工作

### 系统要求

- 已完成 v0.5 的构建
- 有 v0.5 的源码目录

### 检查工具

```bash
# 确认 udev 工具存在
which systemd-udevd
which udevadm
which modprobe
which lsmod
```

---

## 详细构建步骤

### 步骤 1: 从 v0.5 复制基础

**命令**:
```bash
cd ~/linux_class

# 复制 v0.5
cp -a initrd0.5 initrd0.6

# 进入工作目录
cd initrd0.6
```

---

### 步骤 2: 复制 udev 工具

#### 2.1 复制 systemd-udevd

**命令**:
```bash
cd ~/linux_class/initrd0.6

# 创建目录
mkdir -p lib/systemd

# 复制 udevd
cp /lib/systemd/systemd-udevd lib/systemd/

# 复制 udevadm
cp /bin/udevadm bin/
```

#### 2.2 复制 udev 规则

**命令**:
```bash
cd ~/linux_class/initrd0.6

# 创建规则目录
mkdir -p lib/udev/rules.d

# 复制核心规则
cp /lib/udev/rules.d/50-udev-default.rules lib/udev/rules.d/
cp /lib/udev/rules.d/60-persistent-storage.rules lib/udev/rules.d/
cp /lib/udev/rules.d/80-drivers.rules lib/udev/rules.d/
```

**udev 规则说明**:

```
规则文件格式:
ACTION=="add", SUBSYSTEM=="block", ATTR{size}=="?*", NAME="%k"
│              │                  │                   │
│              │                  │                   └── 设备名
│              │                  └─ 设备属性
│              └─ 子系统
└─ 触发动作
```

---

### 步骤 3: 复制内核模块

**目标**: 复制内核驱动模块

**命令**:
```bash
cd ~/linux_class/initrd0.6

# 创建模块目录
mkdir -p lib/modules/6.8.0-90-generic

# 复制模块 (从系统或之前的构建)
cp -r /lib/modules/6.8.0-90-generic/kernel lib/modules/6.8.0-90-generic/ 2>/dev/null || true

# 或者从 iso_build 复制（如果存在）
cp -r iso_build/v1.0-full/source/initrd1.0/lib/modules lib/ 2>/dev/null || true
```

**模块类型**:

| 模块类型 | 示例 | 作用 |
|----------|------|------|
| SCSI 驱动 | scsi_mod, sd_mod | 硬盘访问 |
| ATA 驱动 | ata_piix, libata | IDE/SATA |
| VirtIO 驱动 | virtio, virtio_pci, virtio_net | 虚拟化 |
| 网络驱动 | virtio_net | 网卡支持 |
| USB 驱动 | usbcore, ehci_hcd | USB 支持 |

---

### 步骤 4: 复制依赖库

**命令**:
```bash
cd ~/linux_class/initrd0.6

# udevd 的依赖
ldd /lib/systemd/systemd-udevd | grep -o '/lib[^[:space:]]*' | while read lib; do
    if [ -f "$lib" ]; then
        cp -n "$lib" lib/ 2>/dev/null || true
    fi
done

# udevadm 的依赖
ldd /bin/udevadm | grep -o '/lib[^[:space:]]*' | while read lib; do
    if [ -f "$lib" ]; then
        cp -n "$lib" lib/ 2>/dev/null || true
    fi
done
```

---

### 步骤 5: 更新 init 脚本

**命令**:
```bash
cd ~/linux_class/initrd0.6

cat > init << 'EOF'
#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

echo "[v0.6] Mounting virtual filesystems..."
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# 创建 /run 目录（udev 需要）
mkdir -p /run
mount -t tmpfs none /run

echo "[v0.6] Starting udev daemon..."
/lib/systemd/systemd-udevd --daemon

# 触发设备检测
/bin/udevadm trigger --action=add
/bin/udevadm settle

echo "[v0.6] Hardware drivers loaded!"

echo "Starting interactive shell..."
exec /bin/bash
EOF

chmod +x init
```

**新增内容解析**:

```bash
# 1. 创建 /run 目录
mkdir -p /run
mount -t tmpfs none /run
# udevd 需要在 /run 目录创建 PID 文件和套接字

# 2. 启动 udev 守护进程
/lib/systemd/systemd-udevd --daemon
# 在后台运行 udevd

# 3. 触发设备检测
/bin/udevadm trigger --action=add
# 对所有设备执行 "add" 动作
# 这会让内核重新发送 uevent

# 4. 等待处理完成
/bin/udevadm settle
# 等待所有 uevent 处理完成
# 确保设备节点都已创建
```

---

### 步骤 6: 打包 initrd

**命令**:
```bash
cd ~/linux_class/initrd0.6

find . | cpio -o -H newc | gzip -9 > ../initrd0.6.img

# 查看结果
ls -lh ../initrd0.6.img
# 预期: 约 45MB
```

---

## 原理解析

### udev 启动过程

```
1. 挂载 devtmpfs
        │
        ├── 内核自动创建设备节点
        │   ├── /dev/null
        │   ├── /dev/zero
        │   └── /dev/console
        │
        └── 但缺少具体硬件设备
                │
                ▼
2. 启动 systemd-udevd
        │
        ├── 创建监听 socket
        ├── 读取规则文件
        └── 准备处理事件
                │
                ▼
3. 执行 udevadm trigger
        │
        ├── 向 /sys 中所有设备写入 "add"
        ├── 内核为每个设备发送 uevent
        └── udevd 接收并处理
                │
                ▼
4. 设备节点创建
        │
        ├── 根据规则创建 /dev/xxx
        ├── 设置权限和所有者
        └── 加载必要的驱动
                │
                ▼
5. udevadm settle
        │
        └── 等待所有处理完成
```

### 为什么需要 /run？

```
/run 目录的作用:
├── udevd.pid          # udevd 的 PID 文件
├── udevd.socket       # udevd 的控制套接字
└── 其他运行时数据
```

现代 Linux 系统使用 /run 作为运行时数据目录：
- 比 /var/run 更早可用
- 位于 tmpfs，不占用磁盘
- systemd 需要它

---

## 测试验证

### 启动命令

```bash
cd ~/linux_class
qemu-system-x86_64 \
    -kernel ./vmlinuz-6.8.0-90-generic \
    -initrd initrd0.6.img \
    -m 512 \
    -append "root=/dev/ram0 rw console=ttyS0,115200" \
    -nographic
```

### 预期输出

```
Booting from ROM..
[v0.6] Mounting virtual filesystems...
[v0.6] Starting udev daemon...
[v0.6] Hardware drivers loaded!
Starting interactive shell...
bash-5.1#
```

### 测试命令

```bash
# 1. 查看已加载的模块
lsmod
# 应显示: virtio_net, virtio_pci 等

# 2. 查看 udevd 进程
ps | grep udevd

# 3. 查看设备节点
ls -la /dev/ | grep -E "tty|sda"
# 应显示: tty0, ttyS0, sda 等

# 4. 查看 udev 信息
udevadm info --env | head -10

# 5. 查看块设备
lsblk
```

---

## 故障排查

### 问题 1: /run 目录错误

**现象**: "Failed to create /run/udev: No such file or directory"

**解决**:
```bash
# 在 init 中添加
mkdir -p /run
mount -t tmpfs none /run
```

### 问题 2: 没有设备节点

**现象**: /dev/ 下只有基本设备

**排查**:
```bash
# 检查 udevd 是否运行
ps | grep udevd

# 手动触发
udevadm trigger --action=add
udevadm settle
```

---

## 扩展阅读

- `man 7 udev` - udev 规则语法
- `man 8 systemd-udevd` - udevd 手册
- `man 8 udevadm` - udevadm 手册
- `/sys/kernel/debug/` - 内核调试信息

---

**文档结束**

v0.6 让系统能够识别硬件，是迈向完整系统的关键一步！
EOF
echo "v0.6 文档完成"