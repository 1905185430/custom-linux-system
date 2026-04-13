# Linux Initrd 完整构建指南

本指南详细介绍如何从 v0.5 到 v1.0 逐步构建自定义 Linux initrd 系统。

---

## 📋 前置要求

### 系统环境
- **OS**: Ubuntu 22.04 LTS (推荐)
- **内核**: 6.8.0-90-generic
- **架构**: x86_64

### 必要工具
```bash
sudo apt update
sudo apt install -y \
    qemu-system-x86 \
    qemu-utils \
    cpio \
    gzip \
    build-essential
```

### 验证环境
```bash
./check-env.sh
```

---

## 🏗️ 构建流程

### 方式一：一键构建（推荐）

```bash
# 构建所有版本
make all
# 或
./rebuild_all.sh
```

### 方式二：分步构建

#### Step 1: 构建 v0.5 - 基础系统

```bash
mkdir -p initrd0.5/{bin,dev,etc,proc,sys,tmp,root,sbin,lib,lib64}
chmod 777 initrd0.5/tmp

# 复制基础命令
for cmd in /bin/bash /bin/sh /bin/ls /bin/mkdir /bin/cat \
           /bin/mount /bin/umount /bin/cp /bin/mv /bin/rm \
           /bin/ps /bin/echo; do
    cp "$cmd" initrd0.5/bin/
    # 复制依赖库
    ldd "$cmd" | grep -o '/lib[^[:space:]]*' | xargs -I{} cp {} initrd0.5/lib/
done

# 创建 init 脚本
cat > initrd0.5/init << 'EOF'
#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
echo "[v0.5] Mounting virtual filesystems..."
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
echo "Starting interactive shell..."
exec /bin/bash
EOF
chmod +x initrd0.5/init

# 打包
cd initrd0.5
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd0.5.img
cd ..
```

#### Step 2: 构建 v0.6 - 添加 Udev

```bash
cp -a initrd0.5 initrd0.6
mkdir -p initrd0.6/lib/systemd initrd0.6/lib/udev/rules.d

# 复制 udev 工具
cp /lib/systemd/systemd-udevd initrd0.6/lib/systemd/
cp /bin/udevadm initrd0.6/bin/

# 复制依赖库
ldd /lib/systemd/systemd-udevd | grep -o '/lib[^[:space:]]*' | xargs -I{} cp {} initrd0.6/lib/
ldd /bin/udevadm | grep -o '/lib[^[:space:]]*' | xargs -I{} cp {} initrd0.6/lib/

# 复制 udev 规则
cp -r /lib/udev/rules.d/60-* initrd0.6/lib/udev/rules.d/
cp -r /lib/udev/rules.d/80-net-* initrd0.6/lib/udev/rules.d/

# 复制内核模块（从已有构建或系统复制）
cp -a /lib/modules/6.8.0-90-generic initrd0.6/lib/modules/

# 更新 init 脚本
cat > initrd0.6/init << 'EOF'
#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
echo "[v0.6] Mounting virtual filesystems..."
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
mkdir -p /run
mount -t tmpfs none /run

echo "[v0.6] Starting udev daemon..."
/lib/systemd/systemd-udevd --daemon
/bin/udevadm trigger --action=add
/bin/udevadm settle
echo "[v0.6] Hardware drivers loaded!"

exec /bin/bash
EOF
chmod +x initrd0.6/init

# 打包
cd initrd0.6
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd0.6.img
cd ..
```

#### Step 3: 构建 v0.7 - 添加 Systemd

```bash
cp -a initrd0.6 initrd0.7

# 复制 systemd
cp /lib/systemd/systemd initrd0.7/lib/systemd/
cp /bin/systemctl initrd0.7/bin/

# 复制依赖库
for lib in /lib/systemd/libsystemd-shared-*.so \
           /usr/lib/x86_64-linux-gnu/libseccomp.so.* \
           /usr/lib/x86_64-linux-gnu/libcap*.so.*; do
    [ -f "$lib" ] && cp "$lib" initrd0.7/lib/
done

# 复制 systemd 单元文件
mkdir -p initrd0.7/lib/systemd/system
cp -r /lib/systemd/system/multi-user.target* initrd0.7/lib/systemd/system/
cp -r /lib/systemd/system/sysinit.target* initrd0.7/lib/systemd/system/
cp -r /lib/systemd/system/basic.target* initrd0.7/lib/systemd/system/
cp -r /lib/systemd/system/sockets.target* initrd0.7/lib/systemd/system/
cp /lib/systemd/system/dbus.socket initrd0.7/lib/systemd/system/

# 创建 default.target 链接
ln -sf multi-user.target initrd0.7/lib/systemd/system/default.target

# 创建 bash 服务
mkdir -p initrd0.7/etc/systemd/system/multi-user.target.wants
cat > initrd0.7/etc/systemd/system/bash.service << 'EOF'
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
ln -sf /etc/systemd/system/bash.service \
    initrd0.7/etc/systemd/system/multi-user.target.wants/

# 更新 init 脚本
cat > initrd0.7/init << 'EOF'
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
ln -sf /lib/systemd/systemd /sbin/init 2>/dev/null || true
exec /lib/systemd/systemd
EOF
chmod +x initrd0.7/init

# 打包
cd initrd0.7
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd0.7.img
cd ..
```

#### Step 4: 构建 v0.8 - 添加用户认证

```bash
cp -a initrd0.7 initrd0.8

# 复制用户认证文件
cp /etc/passwd initrd0.8/etc/
cp /etc/group initrd0.8/etc/
cp /etc/nsswitch.conf initrd0.8/etc/
cp /etc/login.defs initrd0.8/etc/

# 创建 shadow 文件（root 密码 123456）
echo 'root:$6$7YAxwvXa321ekF0A$FHdC1C62d96UXoRF5hYxFcx8IhPqq/QFtQhD0/hBT.Glvif/7Pq1HTiFTx/Ydoo3VG7CVkbhW8M0f9.ECM0IB1:19812:0:99999:7:::' > initrd0.8/etc/shadow
chmod 400 initrd0.8/etc/shadow

# 复制 PAM 配置
mkdir -p initrd0.8/etc/pam.d
cp -r /etc/pam.d/* initrd0.8/etc/pam.d/

# 复制登录程序
cp /bin/login initrd0.8/bin/
cp /bin/su initrd0.8/bin/
cp /usr/bin/passwd initrd0.8/usr/bin/

# 复制 PAM 库
mkdir -p initrd0.8/lib/security
cp /lib/x86_64-linux-gnu/security/pam_*.so initrd0.8/lib/security/
cp /lib/x86_64-linux-gnu/libnss_*.so* initrd0.8/lib/

# 复制依赖库
ldd /bin/login | grep -o '/lib[^[:space:]]*' | xargs -I{} cp {} initrd0.8/lib/

# 创建 console-login 服务
rm -f initrd0.8/etc/systemd/system/bash.service
rm -f initrd0.8/etc/systemd/system/multi-user.target.wants/bash.service

cat > initrd0.8/etc/systemd/system/console-login.service << 'EOF'
[Unit]
Description=Console Login Prompt
After=multi-user.target

[Service]
Type=idle
TTYPath=/dev/ttyS0
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
ExecStart=/bin/login
StandardInput=tty-force
StandardOutput=tty
StandardError=tty
Restart=always
RestartSec=0

[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/console-login.service \
    initrd0.8/etc/systemd/system/multi-user.target.wants/

# 打包
cd initrd0.8
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd0.8.img
cd ..
```

#### Step 5: 构建 v0.9 - 添加网络和 SSH

```bash
cp -a initrd0.8 initrd0.9

# 复制网络工具
cp /bin/ip initrd0.9/bin/
cp /bin/ping initrd0.9/bin/
cp /sbin/ifconfig initrd0.9/sbin/
cp /sbin/route initrd0.9/sbin/

# 复制 SSH
cp /usr/sbin/sshd initrd0.9/usr/sbin/
cp /usr/bin/ssh initrd0.9/usr/bin/

# 复制 SSH 配置
mkdir -p initrd0.9/etc/ssh
cp /etc/ssh/sshd_config initrd0.9/etc/ssh/
cp /etc/ssh/ssh_config initrd0.9/etc/ssh/

# 生成 SSH 主机密钥（或复制已有）
ssh-keygen -A -f initrd0.9/etc/ssh/
chmod 600 initrd0.9/etc/ssh/ssh_host_*_key

# 允许 root 登录
echo "PermitRootLogin yes" >> initrd0.9/etc/ssh/sshd_config

# 创建 sshd 目录
mkdir -p initrd0.9/var/empty/sshd
chmod 744 initrd0.9/var/empty/sshd

# 复制依赖库
for cmd in /bin/ip /usr/sbin/sshd; do
    ldd "$cmd" | grep -o '/lib[^[:space:]]*' | xargs -I{} cp -n {} initrd0.9/lib/ 2>/dev/null || true
done

# 打包
cd initrd0.9
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd0.9.img
cd ..
```

#### Step 6: 构建 v1.0 - 完整系统

```bash
cp -a initrd0.9 initrd1.0

# 创建 network.service
cat > initrd1.0/etc/systemd/system/network.service << 'EOF'
[Unit]
Description=Static IP Configuration
After=network-pre.target

[Service]
Type=oneshot
ExecStart=/bin/ip addr replace 192.168.1.100/24 dev eth0
ExecStart=/bin/ip link set eth0 up
ExecStart=/bin/ip route add default via 192.168.1.1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 创建 ssh.service
cat > initrd1.0/etc/systemd/system/ssh.service << 'EOF'
[Unit]
Description=OpenSSH Daemon
After=network.service

[Service]
ExecStart=/usr/sbin/sshd -D
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 启用服务
mkdir -p initrd1.0/etc/systemd/system/multi-user.target.wants
ln -sf /etc/systemd/system/network.service \
    initrd1.0/etc/systemd/system/multi-user.target.wants/
ln -sf /etc/systemd/system/ssh.service \
    initrd1.0/etc/systemd/system/multi-user.target.wants/

# 打包
cd initrd1.0
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd1.0.img
cd ..
```

---

## 🧪 测试验证

### 快速测试
```bash
# 测试 v0.5
./qemu-debug.sh v0.5 nographic

# 测试 v1.0
./qemu-debug.sh v1.0 nographic
```

### 自动化测试
```bash
# 测试所有版本
./test-all-versions.sh

# 查看结果
cat test_results/summary.txt
```

---

## 📦 打包脚本

### 单版本打包
```bash
./build.sh 0.5   # 打包 v0.5
./build.sh 1.0   # 打包 v1.0
```

### 清理构建
```bash
make clean  # 清理源码目录，保留镜像
```

---

## 🔍 故障排查

### 问题：启动时 kernel panic
**原因**: 内存不足  
**解决**: 增加 QEMU 内存参数 `-m 1024`

### 问题：无法找到 init
**原因**: initrd 格式错误  
**解决**: 确保使用 `cpio --format=newc` 打包

### 问题：登录失败
**原因**: PAM 配置错误或 shadow 文件权限  
**解决**: 检查 `/etc/pam.d/` 和 `chmod 400 /etc/shadow`

### 问题：SSH 无法连接
**原因**: 密钥权限或配置错误  
**解决**: `chmod 600 /etc/ssh/ssh_host_*_key`

---

## 📚 参考

- [TEST_REPORT.md](TEST_REPORT.md) - 完整测试报告
- [QEMU_DEBUG_GUIDE.md](QEMU_DEBUG_GUIDE.md) - 调试指南
- [PROJECT_GUIDE.md](PROJECT_GUIDE.md) - 项目概览
