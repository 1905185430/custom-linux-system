# Linux Initrd 系统构建项目

[![Version](https://img.shields.io/badge/version-v1.0-blue.svg)](https://github.com/yourusername/linux-initrd-builder/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

本项目是一个基于 VMware 环境的极简 Linux 系统构建教程实践，从 v0.5 到 v1.0 逐步构建一个功能完整的 initrd (Initial RAM Disk) 系统。

## 项目概述

根据《VMware Linux 系统构建教程》，本项目完成了六个核心任务检查点，构建了一个可在 VMware 虚拟机中运行的自定义 Linux 系统。

## 版本迭代记录

### v0.5 - 基础 Initrd 构建 (4.1MB)
**目标**：创建最基本的可启动 initrd 系统

**完成内容**：
- 创建基础目录结构：`bin`, `dev`, `etc`, `proc`, `sys`, `tmp`, `root`, `sbin`, `lib`, `lib64`
- 复制核心 shell 程序：`/bin/bash`, `/bin/sh`
- 添加基础命令：`ls`, `mkdir`, `cat`, `mount`, `umount`, `cp`, `mv`, `rm`, `ps`, `echo`
- 使用 `ldd` 命令自动处理所有动态链接库依赖
- 编写初始 init 脚本，挂载 proc、sysfs、devtmpfs
- 打包为 `initrd0.5.img`

**技术要点**：
```bash
# 使用 ldd 查找依赖库
ldd /bin/bash | grep -o '/lib[^[:space:]]*' | xargs -I{} cp {} initrd0.5/lib/

# 打包 initrd
cd initrd0.5 && find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd0.5.img
```

---

### v0.6 - 集成 Udev 支持 (45MB)
**目标**：添加硬件设备自动检测和驱动加载

**完成内容**：
- 添加 `systemd-udevd` 和 `udevadm` 工具
- 复制 udev 规则文件到 `/lib/udev/rules.d/`
- 添加硬件驱动模块：
  - SCSI 驱动（磁盘控制器）
  - ATA 驱动（硬盘接口）
  - VirtIO 驱动（虚拟化）
  - 网络驱动（网卡支持）
- 更新 init 脚本，启动 udev 服务并触发设备检测

**技术要点**：
```bash
# 启动 udev 守护进程
/lib/systemd/systemd-udevd --daemon
/bin/udevadm trigger --action=add
/bin/udevadm settle
```

---

### v0.7 - 集成 Systemd 基础服务 (47MB)
**目标**：使用 systemd 接管系统初始化

**完成内容**：
- 添加 systemd 主程序 `/lib/systemd/systemd`
- 添加 systemctl 控制工具
- 复制 systemd 依赖库（libsystemd-shared、libpam、libseccomp 等）
- 添加 systemd 目标单元（target files）
- 更新 init 脚本，由 systemd 接管后续启动流程

**技术要点**：
```bash
# init 脚本最后执行 systemd
exec /lib/systemd/systemd
```

---

### v0.8 - 用户登录认证系统
**目标**：添加用户认证和登录功能

**完成内容**：
- 复制 `/etc/passwd`、`/etc/shadow`、`/etc/group`
- 添加 `/bin/login` 程序
- 复制 PAM 配置文件到 `/etc/pam.d/`
- 复制 `/etc/nsswitch.conf`
- 添加 login 依赖库（libpam、libpam_misc、libaudit 等）

**安全注意事项**：
- shadow 文件需要 root 权限复制
- 确保登录凭证安全

---

### v0.9 - 网络和 SSH 服务
**目标**：添加网络功能和远程访问

**完成内容**：
- 添加网络命令：`ifconfig`、`ip`、`ping`、`route`
- 添加 SSH 服务端 `/usr/sbin/sshd`
- 添加 SSH 客户端 `/usr/bin/ssh`
- 复制 SSH 配置文件到 `/etc/ssh/`
- 配置 SSH 允许 root 登录
- 设置 SSH 密钥文件权限（600）

---

### v1.0 - 完整系统 (48MB)
**目标**：构建功能完整的 Linux 系统

**完成内容**：
- 创建 `network.service`  systemd 服务单元
  - 配置静态 IP（192.168.1.100/24）
  - 设置默认网关（192.168.1.1）
  - 使用 `ip addr replace` 避免重复添加错误
  
- 创建 `ssh.service` systemd 服务单元
  - 后台运行 sshd
  - 配置自动重启

- 启用服务：
  ```bash
  ln -sf /etc/systemd/system/network.service /etc/systemd/system/multi-user.target.wants/
  ln -sf /etc/systemd/system/ssh.service /etc/systemd/system/multi-user.target.wants/
  ```

## 文件结构

```
linux-initrd-builder/
├── README.md                    # 本文件
├── VMware Linux 系统构建教程.md  # 原始教程文档
│
├── initrd0.5/                  # v0.5 源码目录
├── initrd0.5.img               # v0.5 镜像 (4.1MB)
│
├── initrd0.6/                  # v0.6 源码目录
├── initrd0.6.img               # v0.6 镜像 (45MB)
│
├── initrd0.7/                  # v0.7 源码目录
├── initrd0.7.img               # v0.7 镜像 (47MB)
│
├── initrd0.8/                  # v0.8 源码目录
│
├── initrd0.9/                  # v0.9 源码目录
│
└── initrd1.0/                  # v1.0 源码目录
    ├── etc/systemd/system/
    │   ├── network.service     # 网络服务配置
    │   └── ssh.service         # SSH 服务配置
    ├── etc/ssh/
    │   ├── sshd_config         # SSH 服务端配置
    │   └── ssh_host_*_key      # SSH 主机密钥
    └── ...

└── initrd1.0.img               # v1.0 最终镜像 (48MB)
```

## 使用方法

### 1. 在 VMware 中测试

将生成的 initrd 镜像复制到虚拟机：

```bash
sudo cp initrd1.0.img /boot/
```

在 `/etc/grub.d/40_custom` 中添加启动项：

```bash
menuentry "Custom Linux v1.0" {
    linux /boot/vmlinuz-6.8.0-90-generic root=/dev/ram0 rw
    initrd /boot/initrd1.0.img
}
```

更新 GRUB 并重启：

```bash
sudo update-grub
sudo reboot
```

### 2. 制作 U 盘启动盘

参考教程第六部分：

```bash
# 创建 MBR 分区表
sudo parted /dev/sdb mklabel msdos

# 创建 FAT32 分区
sudo parted /dev/sdb mkpart primary fat32 1MiB 100%
sudo parted /dev/sdb set 1 boot on

# 格式化
sudo mkfs.fat -F32 /dev/sdb1

# 安装 GRUB
sudo mkdir -p /mnt/usb
sudo mount /dev/sdb1 /mnt/usb
sudo grub-install --target=i386-pc --recheck --boot-directory=/mnt/usb/boot /dev/sdb

# 复制内核和 initrd
sudo cp initrd1.0.img /mnt/usb/boot/
sudo cp /boot/vmlinuz-6.8.0-90-generic /mnt/usb/boot/

# 创建 grub.cfg
sudo tee /mnt/usb/boot/grub/grub.cfg << 'EOF'
set timeout=5
set default=0

menuentry "Custom Linux v1.0" {
    linux /boot/vmlinuz-6.8.0-90-generic root=/dev/ram0 rw
    initrd /boot/initrd1.0.img
}
EOF

sudo umount /mnt/usb
```

## 技术要点总结

### 1. 动态库依赖处理
使用 `ldd` 命令自动查找并复制所有依赖库：

```bash
ldd /path/to/binary | grep -o '/lib[^[:space:]]*' | xargs -I{} cp {} initrd/lib/
```

### 2. Initrd 打包
使用 cpio + gzip 格式打包：

```bash
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd.img
```

### 3. 关键目录结构
- `/bin` - 基础命令
- `/sbin` - 系统命令
- `/lib` - 动态库
- `/lib/modules` - 内核模块
- `/etc` - 配置文件
- `/dev` - 设备文件（由 devtmpfs 挂载）
- `/proc` - 进程信息（由 procfs 挂载）
- `/sys` - 系统信息（由 sysfs 挂载）
- `/run` - 运行时数据（tmpfs）

### 4. 启动流程
1. 内核加载 initrd
2. 执行 `/init` 脚本
3. 挂载虚拟文件系统（proc、sysfs、devtmpfs）
4. 启动 udev 加载硬件驱动
5. 启动 systemd 接管系统
6. systemd 启动网络服务和 SSH 服务

### 5. 网络配置
使用 `ip addr replace` 代替 `ip addr add`，避免服务重启时因地址已存在而报错。

### 6. SSH 安全
- 确保私钥文件权限为 600
- 配置 `PermitRootLogin yes` 允许 root 远程登录（开发环境）

## 系统要求

- **宿主机**：Ubuntu 22.10
- **内核版本**：6.8.0-90-generic
- **VMware 配置**：8核 CPU，4GB 内存，40GB 硬盘
- **依赖工具**：cpio、gzip、ldd、parted、grub-install

## 已知问题

1. **镜像较大**：v1.0 镜像约 48MB，包含大量驱动模块
2. **静态 IP**：当前使用固定 IP 192.168.1.100，需要根据实际网络环境修改
3. **内核版本绑定**：initrd 与特定内核版本绑定

## 改进方向

1. 精简不必要的驱动模块，减小镜像体积
2. 添加 DHCP 支持，实现动态 IP 配置
3. 添加更多系统服务（如 cron、syslog）
4. 实现真正的根文件系统挂载（而非完全内存运行）

## 参考资料

- [Linux From Scratch](https://www.linuxfromscratch.org/)
- [initramfs 文档](https://www.kernel.org/doc/Documentation/filesystems/ramfs-rootfs-initramfs.txt)
- [systemd 文档](https://systemd.io/)

## 许可证

MIT License

## 作者

根据《VMware Linux 系统构建教程》实践完成

---

**注意**：本项目仅供学习和研究使用，请勿在生产环境中直接使用。
