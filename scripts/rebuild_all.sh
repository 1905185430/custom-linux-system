#!/bin/bash
set -e
export LC_ALL=C

BASE_DIR="/home/xuan/linux_class"
cd "$BASE_DIR"

cleanup() {
    rm -rf initrd0.5 initrd0.6 initrd0.7 initrd0.8 initrd0.9 initrd1.0
}

# 辅助函数：根据二进制文件自动拷贝依赖库
copy_bin_and_deps() {
    local bin=$1
    local initrd_dir=$2
    cp --parents "$bin" "$initrd_dir" 2>/dev/null || cp "$bin" "$initrd_dir/bin/"
    
    local deps=$(ldd "$bin" 2>/dev/null | grep -o '/lib[^[:space:]]*' | sort | uniq)
    for dep in $deps; do
        if [ -f "$dep" ]; then
            # 把所有依赖丢进 lib
            cp -n "$dep" "$initrd_dir/lib/" 2>/dev/null || true
            # 如果是 ld-linux，也放一份在 lib64 保证兼容
            if [[ "$dep" == *ld-linux-x86-64.so* ]]; then
                cp -n "$dep" "$initrd_dir/lib64/" 2>/dev/null || true
            fi
        fi
    done
}

echo "Starting exact rebuild according to README..."
cleanup

# ==========================================
# v0.5 基础 initrd 构建
# ==========================================
echo "Building v0.5..."
mkdir -p initrd0.5/{bin,dev,etc,proc,sys,tmp,root,sbin,lib,lib64}
chmod 777 initrd0.5/tmp

for cmd in /bin/bash /bin/sh /bin/ls /bin/mkdir /bin/cat /bin/mount /bin/umount /bin/cp /bin/mv /bin/rm /bin/ps /bin/echo; do
    copy_bin_and_deps "$cmd" "initrd0.5"
done

cat << 'EOF' > initrd0.5/init
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
(cd initrd0.5 && find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd0.5.img 2>/dev/null)

# ==========================================
# v0.6 Udev 支持
# ==========================================
echo "Building v0.6..."
cp -a initrd0.5 initrd0.6
mkdir -p initrd0.6/lib/systemd initrd0.6/lib/udev/rules.d

copy_bin_and_deps "/lib/systemd/systemd-udevd" "initrd0.6"
copy_bin_and_deps "/bin/udevadm" "initrd0.6"

# 复制 udev rules
if [ -d /lib/udev/rules.d ]; then
    cp -r /lib/udev/rules.d/60-* initrd0.6/lib/udev/rules.d/ 2>/dev/null || true
    cp -r /lib/udev/rules.d/80-net-* initrd0.6/lib/udev/rules.d/ 2>/dev/null || true
fi

# 从 iso_build 偷取之前学生辛辛苦苦弄好的精准 kernel modules 树
if [ -d iso_build/v1.0-full/source/initrd1.0/lib/modules ]; then
    cp -a iso_build/v1.0-full/source/initrd1.0/lib/modules initrd0.6/lib/
fi

cat << 'EOF' > initrd0.6/init
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

echo "Starting interactive shell..."
exec /bin/bash
EOF
chmod +x initrd0.6/init
(cd initrd0.6 && find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd0.6.img 2>/dev/null)

# ==========================================
# v0.7 Systemd 基础服务
# ==========================================
echo "Building v0.7..."
cp -a initrd0.6 initrd0.7

copy_bin_and_deps "/lib/systemd/systemd" "initrd0.7"
copy_bin_and_deps "/bin/systemctl" "initrd0.7"

# 补充 Systemd 需要的核心库和单元
mkdir -p initrd0.7/lib/systemd/system
for lib in /lib/systemd/libsystemd-shared-*.so /usr/lib/x86_64-linux-gnu/libseccomp.so.* /usr/lib/x86_64-linux-gnu/libcap*.so.*; do
    if [ -f "$lib" ]; then cp -n "$lib" initrd0.7/lib/ 2>/dev/null || true; fi
done
cp -r /lib/systemd/system/multi-user.target* initrd0.7/lib/systemd/system/ 2>/dev/null || true
cp -r /lib/systemd/system/sysinit.target* initrd0.7/lib/systemd/system/ 2>/dev/null || true
cp -r /lib/systemd/system/basic.target* initrd0.7/lib/systemd/system/ 2>/dev/null || true
cp -r /lib/systemd/system/sockets.target* initrd0.7/lib/systemd/system/ 2>/dev/null || true
cp -r /lib/systemd/system/dbus.socket initrd0.7/lib/systemd/system/ 2>/dev/null || true

# 补充 default.target 指向
ln -sf multi-user.target initrd0.7/lib/systemd/system/default.target
mkdir -p initrd0.7/etc/systemd/system/multi-user.target.wants

cat << 'EOF' > initrd0.7/etc/systemd/system/bash.service
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
ln -sf /etc/systemd/system/bash.service initrd0.7/etc/systemd/system/multi-user.target.wants/

cat << 'EOF' > initrd0.7/init
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
(cd initrd0.7 && find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd0.7.img 2>/dev/null)

# ==========================================
# v0.8 用户登录认证系统
# ==========================================
echo "Building v0.8..."
cp -a initrd0.7 initrd0.8

cp /etc/passwd initrd0.8/etc/
echo 'root:$6$7YAxwvXa321ekF0A$FHdC1C62d96UXoRF5hYxFcx8IhPqq/QFtQhD0/hBT.Glvif/7Pq1HTiFTx/Ydoo3VG7CVkbhW8M0f9.ECM0IB1:19812:0:99999:7:::' > initrd0.8/etc/shadow || true
chmod 400 initrd0.8/etc/shadow || true
cp /etc/group initrd0.8/etc/
cp /etc/nsswitch.conf initrd0.8/etc/
cp -r /etc/pam.d initrd0.8/etc/
cat << 'EOF' > initrd0.8/etc/pam.d/common-auth
auth	required	pam_unix.so nullok
EOF
cat << 'EOF' > initrd0.8/etc/pam.d/common-account
account	required	pam_unix.so
EOF
cat << 'EOF' > initrd0.8/etc/pam.d/common-session
session	required	pam_unix.so
session	optional	pam_env.so readenv=1
session	optional	pam_env.so readenv=1 envfile=/etc/default/locale
EOF
cat << 'EOF' > initrd0.8/etc/pam.d/su
auth      sufficient  pam_rootok.so
auth      required    pam_unix.so nullok
account   required    pam_unix.so
session   required    pam_unix.so
EOF
cat << 'EOF' > initrd0.8/etc/pam.d/su-l
#%PAM-1.0
auth       include    su
account    include    su
password   include    su
session    include    su
EOF
cat << 'EOF' > initrd0.8/etc/pam.d/login
# Minimal PAM stack for initrd console login (v0.8)

auth      requisite   pam_nologin.so
auth      required    pam_unix.so nullok

account   required    pam_unix.so

session   required    pam_unix.so
session   optional    pam_env.so readenv=1
session   optional    pam_env.so readenv=1 envfile=/etc/default/locale
session   optional    pam_limits.so

password  required    pam_unix.so yescrypt
EOF

copy_bin_and_deps "/bin/login" "initrd0.8"
copy_bin_and_deps "/bin/su" "initrd0.8"

# 提取 /etc/login.defs 消除 login 的警告与降级
cp /etc/login.defs initrd0.8/etc/ 2>/dev/null || true
if [ -f initrd0.8/etc/login.defs ]; then
    sed -i 's/^LOGIN_TIMEOUT[[:space:]]\+.*/LOGIN_TIMEOUT\t\t0/' initrd0.8/etc/login.defs
fi

# nsswitch 与 pam_*.so 由于是 dlopen 动态加载模块，系统 ldd 无法顺藤摸瓜，必须对其显式递归解析依赖
for so in /lib/x86_64-linux-gnu/libnss_*.so* /usr/lib/x86_64-linux-gnu/libnss_*.so* /lib/x86_64-linux-gnu/security/pam_*.so; do
    if [ -f "$so" ]; then
        copy_bin_and_deps "$so" "initrd0.8"
    fi
done

# PAM 特殊约定：除了 /lib ，其默认硬编码还会在对应的 security 寻找库
mkdir -p initrd0.8/lib/security
cp -n /lib/x86_64-linux-gnu/security/pam_*.so initrd0.8/lib/security/ 2>/dev/null || true

# 补充密码修改工具
copy_bin_and_deps "/usr/bin/passwd" "initrd0.8"

# 取消 v0.7 中的直接进入 Bash 裸奔机制，将其正式切换为强制的开机身份拦截认证
rm -f initrd0.8/etc/systemd/system/bash.service
rm -f initrd0.8/etc/systemd/system/multi-user.target.wants/bash.service
rm -f initrd0.8/lib/systemd/system/multi-user.target.wants/bash.service
find initrd0.8/etc/systemd/system -type l -lname '*/bash.service' -delete 2>/dev/null || true
cat << 'EOF' > initrd0.8/etc/systemd/system/console-login.service
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
ln -sf /etc/systemd/system/console-login.service initrd0.8/etc/systemd/system/multi-user.target.wants/

(cd initrd0.8 && find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd0.8.img 2>/dev/null)

# ==========================================
# v0.9 网络和 SSH
# ==========================================
echo "Building v0.9..."
cp -a initrd0.8 initrd0.9

for cmd in /bin/ip /bin/ping /sbin/ifconfig /sbin/route /usr/sbin/sshd /usr/bin/ssh; do
    if [ ! -f "$cmd" ]; then continue; fi
    copy_bin_and_deps "$cmd" "initrd0.9"
done

cp -r /etc/ssh initrd0.9/etc/ 2>/dev/null || true
chmod 600 initrd0.9/etc/ssh/ssh_host_*_key 2>/dev/null || true
echo "PermitRootLogin yes" >> initrd0.9/etc/ssh/sshd_config 2>/dev/null || true

# bash login shell dependencies for ssh
cp /etc/profile initrd0.9/etc/ 2>/dev/null || true
mkdir -p initrd0.9/var/empty/sshd
chmod 744 initrd0.9/var/empty/sshd

(cd initrd0.9 && find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd0.9.img 2>/dev/null)

# ==========================================
# v1.0 完整系统 (开机自启服务)
# ==========================================
echo "Building v1.0..."
cp -a initrd0.9 initrd1.0

mkdir -p initrd1.0/etc/systemd/system/multi-user.target.wants

cat << 'EOF' > initrd1.0/etc/systemd/system/network.service
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

cat << 'EOF' > initrd1.0/etc/systemd/system/ssh.service
[Unit]
Description=OpenSSH Daemon
After=network.service

[Service]
ExecStart=/usr/sbin/sshd -D
Restart=always

[Install]
WantedBy=multi-user.target
EOF

ln -sf /etc/systemd/system/network.service initrd1.0/etc/systemd/system/multi-user.target.wants/
ln -sf /etc/systemd/system/ssh.service initrd1.0/etc/systemd/system/multi-user.target.wants/

(cd initrd1.0 && find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initrd1.0.img 2>/dev/null)

echo "Rebuild Complete!"
