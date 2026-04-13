#!/bin/bash
# v0.8 完整构建和测试工作流
# 功能：用户登录认证系统 (PAM)

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${YELLOW}[STEP]${NC} $1"
}

# 步骤 1: 清理旧版本
cleanup() {
    log_step "1/10 清理旧版本..."
    rm -rf initrd0.8 initrd0.8.img
    log_success "清理完成"
}

# 步骤 2: 从 v0.7 复制基础
copy_base() {
    log_step "2/10 从 v0.7 复制基础系统..."
    if [ ! -d "initrd0.7" ]; then
        log_error "initrd0.7 不存在，请先构建 v0.7"
        exit 1
    fi
    cp -a initrd0.7 initrd0.8
    log_success "基础系统复制完成"
}

# 步骤 3: 复制用户认证文件
copy_auth_files() {
    log_step "3/10 复制用户认证文件..."
    
    # passwd 文件
    cp /etc/passwd initrd0.8/etc/
    
    # shadow 文件 - 密码 123456
    cat > initrd0.8/etc/shadow << 'EOF'
root:$6$7YAxwvXa321ekF0A$FHdC1C62d96UXoRF5hYxFcx8IhPqq/QFtQhD0/hBT.Glvif/7Pq1HTiFTx/Ydoo3VG7CVkbhW8M0f9.ECM0IB1:19812:0:99999:7:::
EOF
    chmod 400 initrd0.8/etc/shadow
    
    # group 文件
    cp /etc/group initrd0.8/etc/
    
    # nsswitch.conf
    cp /etc/nsswitch.conf initrd0.8/etc/ 2>/dev/null || true
    
    log_success "用户认证文件复制完成"
}

# 步骤 4: 复制登录程序
copy_login() {
    log_step "4/10 复制登录程序..."
    
    # login 程序
    cp /bin/login initrd0.8/bin/
    
    # su 程序
    cp /bin/su initrd0.8/bin/ 2>/dev/null || true
    
    # passwd 程序
    cp /usr/bin/passwd initrd0.8/usr/bin/ 2>/dev/null || true
    
    log_success "登录程序复制完成"
}

# 步骤 5: 复制 PAM 配置
copy_pam_config() {
    log_step "5/10 复制 PAM 配置..."
    
    mkdir -p initrd0.8/etc/pam.d
    
    # login PAM 配置
    cat > initrd0.8/etc/pam.d/login << 'EOF'
# PAM configuration for login
auth       required   pam_unix.so nullok
account    required   pam_unix.so
session    required   pam_unix.so
EOF
    
    # common-auth
    cat > initrd0.8/etc/pam.d/common-auth << 'EOF'
auth    required    pam_unix.so nullok
EOF
    
    # common-account
    cat > initrd0.8/etc/pam.d/common-account << 'EOF'
account required    pam_unix.so
EOF
    
    # common-session
    cat > initrd0.8/etc/pam.d/common-session << 'EOF'
session required    pam_unix.so
EOF
    
    # su PAM 配置
    cat > initrd0.8/etc/pam.d/su << 'EOF'
auth      sufficient  pam_rootok.so
auth      required    pam_unix.so nullok
account   required    pam_unix.so
session   required    pam_unix.so
EOF
    
    log_success "PAM 配置复制完成"
}

# 步骤 6: 复制 PAM 库
copy_pam_libs() {
    log_step "6/10 复制 PAM 库..."
    
    mkdir -p initrd0.8/lib/security
    
    # 复制 PAM 模块
    for pam_mod in pam_unix.so pam_rootok.so pam_deny.so pam_permit.so; do
        if [ -f "/lib/x86_64-linux-gnu/security/$pam_mod" ]; then
            cp "/lib/x86_64-linux-gnu/security/$pam_mod" initrd0.8/lib/security/
        fi
    done
    
    # 复制 PAM 主库
    cp /lib/x86_64-linux-gnu/libpam.so.0 initrd0.8/lib/ 2>/dev/null || true
    cp /lib/x86_64-linux-gnu/libpam_misc.so.0 initrd0.8/lib/ 2>/dev/null || true
    
    log_success "PAM 库复制完成"
}

# 步骤 7: 复制 NSS 库
copy_nss_libs() {
    log_step "7/10 复制 NSS 库..."
    
    # NSS 库用于用户查找
    for nss_lib in /lib/x86_64-linux-gnu/libnss_files.so.2 /lib/x86_64-linux-gnu/libnss_compat.so.2; do
        if [ -f "$nss_lib" ]; then
            cp "$nss_lib" initrd0.8/lib/
        fi
    done
    
    log_success "NSS 库复制完成"
}

# 步骤 8: 复制依赖库
copy_dependencies() {
    log_step "8/10 复制程序依赖库..."
    
    # login 的依赖
    ldd /bin/login | grep -o '/lib[^[:space:]]*' | while read lib; do
        if [ -f "$lib" ]; then
            cp -n "$lib" initrd0.8/lib/ 2>/dev/null || true
        fi
    done
    
    # PAM 库的依赖
    ldd /lib/x86_64-linux-gnu/libpam.so.0 2>/dev/null | grep -o '/lib[^[:space:]]*' | while read lib; do
        if [ -f "$lib" ]; then
            cp -n "$lib" initrd0.8/lib/ 2>/dev/null || true
        fi
    done
    
    log_success "依赖库复制完成"
}

# 步骤 9: 创建 systemd 服务
create_systemd_service() {
    log_step "9/10 创建 systemd 登录服务..."
    
    mkdir -p initrd0.8/etc/systemd/system/multi-user.target.wants
    
    # 创建 console-login 服务
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
    
    # 启用服务
    ln -sf /etc/systemd/system/console-login.service initrd0.8/etc/systemd/system/multi-user.target.wants/
    
    # 移除 v0.7 的 bash 服务
    rm -f initrd0.8/etc/systemd/system/multi-user.target.wants/bash.service
    rm -f initrd0.8/etc/systemd/system/bash.service
    
    log_success "systemd 服务创建完成"
}

# 步骤 10: 更新 init 脚本
update_init() {
    log_step "10/10 更新 init 脚本..."
    
    cat > initrd0.8/init << 'EOF'
#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

echo "[v0.8] Mounting virtual filesystems..."
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# 创建必要的运行时目录
mkdir -p /run /run/udev /var/run

echo "[v0.8] Starting udev daemon..."
/lib/systemd/systemd-udevd --daemon
/bin/udevadm trigger --action=add
/bin/udevadm settle
echo "[v0.8] Hardware drivers loaded!"

echo "[v0.8] Starting systemd..."
ln -sf /lib/systemd/systemd /sbin/init 2>/dev/null || true
exec /lib/systemd/systemd
EOF
    chmod +x initrd0.8/init
    
    log_success "init 脚本更新完成"
}

# 打包镜像
pack_image() {
    log_step "打包 initrd 镜像..."
    cd initrd0.8
    find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -1 > ../initrd0.8.img
    cd ..
    
    if [ -f "initrd0.8.img" ]; then
        local size=$(ls -lh initrd0.8.img | awk '{print $5}')
        log_success "镜像打包完成: initrd0.8.img ($size)"
    else
        log_error "镜像打包失败"
        exit 1
    fi
}

# 验证镜像
verify_image() {
    log_step "验证镜像..."
    
    # 检查 gzip 完整性
    if gzip -t initrd0.8.img 2>/dev/null; then
        log_success "gzip 完整性检查通过"
    else
        log_error "gzip 完整性检查失败"
        return 1
    fi
    
    # 检查关键文件
    local temp_dir=$(mktemp -d)
    gzip -dc initrd0.8.img | cpio -id --quiet -D "$temp_dir" 2>/dev/null
    
    local missing=0
    for file in init bin/login etc/shadow etc/passwd etc/pam.d/login lib/security/pam_unix.so; do
        if [ -f "$temp_dir/$file" ]; then
            log_info "✓ $file 存在"
        else
            log_error "✗ $file 缺失"
            missing=1
        fi
    done
    
    rm -rf "$temp_dir"
    
    if [ $missing -eq 0 ]; then
        log_success "所有关键文件检查通过"
        return 0
    else
        log_error "部分文件缺失"
        return 1
    fi
}

# 测试镜像
test_image() {
    log_step "启动 QEMU 测试..."
    log_info "启动命令:"
    log_info "qemu-system-x86_64 -kernel ./vmlinuz-6.8.0-90-generic -initrd initrd0.8.img -m 1024 -append 'root=/dev/ram0 rw console=ttyS0,115200' -nographic"
    
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  v0.8 构建完成！${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo "登录信息:"
    echo "  用户名: root"
    echo "  密码: 123456"
    echo ""
    echo "启动命令:"
    echo "  cd ~/linux_class"
    echo "  qemu-system-x86_64 -kernel ./vmlinuz-6.8.0-90-generic -initrd initrd0.8.img -m 1024 -append 'root=/dev/ram0 rw console=ttyS0,115200' -nographic"
    echo ""
    echo "退出 QEMU: Ctrl+A 然后 X"
}

# 主流程
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  v0.8 用户登录认证系统构建工作流${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    cleanup
    copy_base
    copy_auth_files
    copy_login
    copy_pam_config
    copy_pam_libs
    copy_nss_libs
    copy_dependencies
    create_systemd_service
    update_init
    pack_image
    verify_image
    test_image
    
    echo ""
    log_success "v0.8 构建工作流完成！"
}

main "$@"
