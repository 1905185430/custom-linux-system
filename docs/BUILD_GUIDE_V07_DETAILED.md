# Linux Initrd v0.7 详细构建教程

## 添加 Systemd 系统初始化

**文档版本**: 1.0  
**作者**: 璇璇子  
**日期**: 2025-04-13  
**前置版本**: v0.6  
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

### 什么是 v0.7？

v0.7 在 v0.6（udev 硬件检测）的基础上，使用 **systemd** 接管系统初始化。这是现代 Linux 发行版的标准初始化系统。

### 为什么需要 systemd？

| v0.6 的问题 | systemd 的解决 |
|------------|---------------|
| 手动管理进程 | 自动服务管理 |
| 启动顺序混乱 | 依赖关系管理 |
| 无法监控服务 | 自动重启失败服务 |
| 缺乏日志 | 集中日志管理 |

### v0.7 新增功能

✅ **systemd PID 1** - 作为 init 进程  
✅ **服务管理** - systemctl 命令  
✅ **目标系统** - multi-user.target  
✅ **自动服务** - bash.service 自动启动  
✅ **并行启动** - 提高启动速度  

### init vs systemd

```
传统 init (SysV):
    /etc/init.d/
    ├── S01network    (启动网络)
    ├── S02sshd       (启动 SSH)
    └── S03cron       (启动定时任务)
    
    问题：顺序启动，慢；依赖管理弱

现代 systemd:
    /lib/systemd/system/
    ├── network.service    (可以并行)
    ├── ssh.service        (依赖 network)
    └── cron.service       (独立启动)
    
    优势：并行启动，依赖管理，自动重启
```

---

## 基本概念

### 1. 什么是 systemd？

**systemd** 是 Linux 的系统和服务管理器，它：
- 作为 PID 1（第一个用户空间进程）
- 管理系统启动
- 管理后台服务
- 提供日志、定时任务等功能

### 2. systemd 核心概念

#### 单元（Unit）

systemd 管理的基本单位：

| 单元类型 | 扩展名 | 作用 | 示例 |
|----------|--------|------|------|
| Service | .service | 后台服务 | ssh.service |
| Target | .target | 目标状态 | multi-user.target |
| Socket | .socket | 套接字 | dbus.socket |
| Device | .device | 设备 | dev-sda.device |
| Mount | .mount | 挂载点 | home.mount |

#### 目标（Target）

```
启动目标层级：

graphical.target      (图形界面)
       │
       ├── multi-user.target    (多用户命令行)
       │         │
       │         ├── basic.target
       │         │       │
       │         │       └── sysinit.target  (系统初始化)
       │         │
       │         └── network.target
       │
       └── display-manager.service

常用目标：
- sysinit.target    : 系统初始化完成
- basic.target      : 基本系统准备
- multi-user.target : 多用户模式（命令行）
- graphical.target  : 图形界面模式
```

#### 服务状态

```
服务生命周期：

      ┌─────────────┐
      │   inactive  │  (未启动)
      └──────┬──────┘
             │ systemctl start
             ▼
      ┌─────────────┐
      │   active    │  (运行中)
      │  (running)  │
      └──────┬──────┘
             │ systemctl stop
             ▼
      ┌─────────────┐
      │   inactive  │  (已停止)
      └─────────────┘
             │
             └── 异常退出 ──▶ failed
```

### 3. systemctl 命令

#### 服务控制

```bash
# 启动服务
systemctl start service_name

# 停止服务
systemctl stop service_name

# 重启服务
systemctl restart service_name

# 查看状态
systemctl status service_name
```

#### 开机自启

```bash
# 启用开机自启
systemctl enable service_name

# 禁用开机自启
systemctl disable service_name

# 查看是否启用
systemctl is-enabled service_name
```

#### 目标切换

```bash
# 切换到多用户模式
systemctl isolate multi-user.target

# 查看当前目标
systemctl get-default

# 设置默认目标
systemctl set-default multi-user.target
```

### 4. 服务文件格式

```ini
[Unit]
Description=Service description
After=network.target          ; 在 network 之后启动
Requires=other.service        ; 依赖其他服务

[Service]
Type=simple                   ; 服务类型
ExecStart=/path/to/command    ; 启动命令
Restart=always                ; 总是重启
RestartSec=5                  ; 5秒后重启

[Install]
WantedBy=multi-user.target    ; 属于 multi-user 目标
```

**Type 类型**:

| 类型 | 说明 |
|------|------|
| simple | 前台运行（默认） |
| forking | 后台运行（fork） |
| oneshot | 执行一次 |
| idle | 空闲时启动 |

---

## 准备工作

### 系统要求

- 已完成 v0.6 的构建
- 有 v0.6 的源码目录

### 检查工具

```bash
which systemctl
which systemd
ls /lib/systemd/systemd
```

---

## 详细构建步骤

### 步骤 1: 从 v0.6 复制基础

```bash
cd ~/linux_class
cp -a initrd0.6 initrd0.7
cd initrd0.7
```

---

### 步骤 2: 复制 systemd

#### 2.1 复制主程序

```bash
cd ~/linux_class/initrd0.7

# 复制 systemd
cp /lib/systemd/systemd lib/systemd/

# 复制 systemctl
cp /bin/systemctl bin/

# 复制 systemctl 依赖
ldd /bin/systemctl | grep -o '/lib[^[:space:]]*' | while read lib; do
    [ -f "$lib" ] && cp -n "$lib" lib/ 2>/dev/null || true
done
```

#### 2.2 复制核心库

```bash
cd ~/linux_class/initrd0.7

# 复制 systemd 共享库
for lib in /lib/systemd/libsystemd-shared-*.so; do
    [ -f "$lib" ] && cp "$lib" lib/
done

# 复制其他依赖
cp /usr/lib/x86_64-linux-gnu/libseccomp.so.* lib/ 2>/dev/null || true
cp /usr/lib/x86_64-linux-gnu/libcap*.so.* lib/ 2>/dev/null || true
```

#### 2.3 复制 systemd 单元文件

```bash
cd ~/linux_class/initrd0.7

# 复制核心单元
mkdir -p lib/systemd/system
cp -r /lib/systemd/system/multi-user.target* lib/systemd/system/
cp -r /lib/systemd/system/sysinit.target* lib/systemd/system/
cp -r /lib/systemd/system/basic.target* lib/systemd/system/
cp -r /lib/systemd/system/sockets.target* lib/systemd/system/
cp /lib/systemd/system/dbus.socket lib/systemd/system/ 2>/dev/null || true

# 创建默认目标链接
ln -sf multi-user.target lib/systemd/system/default.target
```

---

### 步骤 3: 创建服务

#### 3.1 创建 bash.service

```bash
cd ~/linux_class/initrd0.7

# 创建服务目录
mkdir -p etc/systemd/system/multi-user.target.wants

# 创建 bash 服务
cat > etc/systemd/system/bash.service << 'EOF'
[Unit]
Description=Interactive Bash Shell
After=multi-user.target

[Service]
Type=idle
ExecStart=/bin/bash
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit

[Install]
WantedBy=multi-user.target
EOF

# 启用服务
ln -sf /etc/systemd/system/bash.service \
    etc/systemd/system/multi-user.target.wants/
```

**服务配置说明**:

```ini
[Unit]
Description=Interactive Bash Shell    ; 服务描述
After=multi-user.target               ; 在 multi-user 之后启动

[Service]
Type=idle                             ; 空闲时启动（其他服务后）
ExecStart=/bin/bash                   ; 启动 bash
StandardInput=tty-force               ; 强制使用 TTY 输入
StandardOutput=inherit                ; 继承标准输出
StandardError=inherit                 ; 继承标准错误

[Install]
WantedBy=multi-user.target            ; 属于 multi-user 目标
```

---

### 步骤 4: 更新 init 脚本

```bash
cd ~/linux_class/initrd0.7

cat > init << 'EOF'
#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

echo "[v0.7] Mounting virtual filesystems..."
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

echo "[v0.7] Starting udev daemon..."
/lib/systemd/systemd-udevd --daemon
/bin/udevadm trigger --action=add
/bin/udevadm settle
echo "[v0.7] Hardware drivers loaded!"

echo "[v0.7] Starting systemd..."
# 创建 /sbin/init 链接（兼容）
ln -sf /lib/systemd/systemd /sbin/init 2>/dev/null || true

# 启动 systemd
exec /lib/systemd/systemd
EOF

chmod +x init
```

**关键变化**:

```bash
# 原来是：
exec /bin/bash

# 现在是：
exec /lib/systemd/systemd
# systemd 会接管系统，然后启动 bash.service
```

---

### 步骤 5: 打包

```bash
cd ~/linux_class/initrd0.7

find . | cpio -o -H newc | gzip -9 > ../initrd0.7.img

ls -lh ../initrd0.7.img
# 预期: 约 48MB
```

---

## 原理解析

### systemd 启动流程

```
1. 内核启动，执行 /init
        │
        ├── 挂载 proc/sys/dev
        ├── 启动 udev
        └── 加载驱动
                │
                ▼
2. /init 执行 systemd
   exec /lib/systemd/systemd
        │
        ├── systemd 成为 PID 1
        ├── 解析单元文件
        └── 确定启动目标
                │
                ▼
3. 达到 multi-user.target
        │
        ├── 启动 basic.target
        ├── 启动 sockets.target
        └── 启动各个服务
                │
                ▼
4. 启动 bash.service
        │
        └── 因为 WantedBy=multi-user.target
                │
                ▼
5. 用户看到 shell 提示符
```

### PID 1 的重要性

```
Linux 进程树：

        systemd (PID 1)    ← 所有进程的祖先
            │
            ├── udevd
            │
            ├── bash (你的 shell)
            │       │
            │       └── 你运行的命令
            │
            └── 其他服务

如果 PID 1 退出：
    └── 内核 panic！
    └── 系统崩溃！

所以 init 脚本用 exec：
    └── 替换当前进程，不创建子进程
---

## 测试验证

### 启动命令

```bash
cd ~/linux_class
qemu-system-x86_64 \
    -kernel ./vmlinuz-6.8.0-90-generic \
    -initrd initrd0.7.img \
    -m 512 \
    -append "root=/dev/ram0 rw console=ttyS0,115200" \
    -nographic
```

### 预期输出

```
[v0.7] Mounting virtual filesystems...
[v0.7] Starting udev daemon...
[v0.7] Hardware drivers loaded!
[v0.7] Starting systemd...
[  OK  ] Reached target multi-user.target
[  OK  ] Started bash.service
bash-5.1#
```

### 测试命令

```bash
# 1. 验证 systemd 是 PID 1
ps -p 1
# 应显示 systemd

# 2. 查看 systemd 版本
systemctl --version

# 3. 查看系统状态
systemctl status

# 4. 列出所有服务
systemctl list-units

# 5. 查看 bash 服务状态
systemctl status bash.service

# 6. 查看当前目标
systemctl get-default
```

---

## 故障排查

### 问题 1: systemd 无法启动

**现象**: 卡在 "Starting systemd..."

**排查**:
```bash
# 检查 systemd 是否存在
ls -la /lib/systemd/systemd

# 检查权限
file /lib/systemd/systemd
```

### 问题 2: 服务无法启动

**现象**: bash.service 失败

**排查**:
```bash
# 查看服务状态
systemctl status bash.service

# 检查服务文件语法
systemd-analyze verify /etc/systemd/system/bash.service
```

### 问题 3: 目标无法达到

**现象**: 无法达到 multi-user.target

**排查**:
```bash
# 查看依赖关系
systemctl list-dependencies multi-user.target

# 查看失败的单元
systemctl --failed
```

---

## 总结

### v0.7 关键要点

1. **systemd 作为 PID 1** - 接管系统初始化
2. **单元（Unit）** - 服务、目标、套接字
3. **目标（Target）** - 系统状态（multi-user.target）
4. **服务文件** - .service 配置文件
5. **systemctl** - 管理服务的命令

### v0.7 vs v0.6

| 特性 | v0.6 | v0.7 |
|------|------|------|
| 初始化 | init 脚本 | systemd |
| 服务管理 | 无 | systemctl |
| 启动顺序 | 线性 | 并行（依赖管理） |
| 自动重启 | 无 | 支持 |

### 下一步

继续学习 **v0.8** - 添加用户登录认证！

---

**文档结束**
