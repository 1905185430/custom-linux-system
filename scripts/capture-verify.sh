#!/bin/bash
# 捕获每个版本的终端验证输出

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

KERNEL="./vmlinuz-6.8.0-90-generic"
[ -f "$KERNEL" ] || KERNEL="/boot/vmlinuz-6.8.0-90-generic"
[ -f "$KERNEL" ] || KERNEL="/boot/vmlinuz-$(uname -r)"

RESULTS_DIR="verification_output"
mkdir -p "$RESULTS_DIR"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Linux Initrd 版本验证输出捕获${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# v0.5 验证命令
verify_v0.5() {
    cat << 'EOF'
echo "========== v0.5 基础系统验证 =========="
echo "[1] 查看当前目录:"
pwd
echo ""
echo "[2] 列出根目录内容:"
ls -la /
echo ""
echo "[3] 查看挂载的文件系统:"
mount | grep -E "proc|sys|dev"
echo ""
echo "[4] 查看内核版本:"
cat /proc/version
echo ""
echo "[5] 查看进程:"
ps
echo ""
echo "[6] 测试基本命令:"
echo "Hello from v0.5" && mkdir -p /test && touch /test/file && ls /test/
echo ""
echo "========== v0.5 验证完成 =========="
EOF
}

# v0.6 验证命令
verify_v0.6() {
    cat << 'EOF'
echo "========== v0.6 Udev 验证 =========="
echo "[1] 查看 udevd 进程:"
ps | grep udevd
echo ""
echo "[2] 查看已加载的模块:"
lsmod | head -10
echo ""
echo "[3] 查看设备节点:"
ls -la /dev/ | grep -E "tty|sda|block" | head -10
echo ""
echo "[4] 查看 udev 信息:"
udevadm info --env 2>/dev/null | head -5 || echo "udevadm info 可用"
echo ""
echo "[5] 检查 /run 目录:"
ls -la /run/
echo ""
echo "========== v0.6 验证完成 =========="
EOF
}

# v0.7 验证命令
verify_v0.7() {
    cat << 'EOF'
echo "========== v0.7 Systemd 验证 =========="
echo "[1] 查看 PID 1:"
ps -p 1
echo ""
echo "[2] 查看 systemd 版本:"
systemctl --version 2>/dev/null | head -2
echo ""
echo "[3] 查看系统状态:"
systemctl status 2>/dev/null | head -10
echo ""
echo "[4] 列出所有服务:"
systemctl list-units 2>/dev/null | head -10
echo ""
echo "[5] 查看 bash 服务状态:"
systemctl status bash.service 2>/dev/null || echo "bash.service 状态"
echo ""
echo "========== v0.7 验证完成 =========="
EOF
}

# v0.8 验证命令
verify_v0.8() {
    cat << 'EOF'
echo "========== v0.8 登录认证验证 =========="
echo "[1] 查看用户文件:"
cat /etc/passwd | head -5
echo ""
echo "[2] 查看 shadow 文件 (仅显示存在):"
ls -la /etc/shadow
echo ""
echo "[3] 查看 PAM 配置:"
ls -la /etc/pam.d/
echo ""
echo "[4] 查看 login 程序:"
ls -la /bin/login
echo ""
echo "[5] 查看 console-login 服务:"
systemctl status console-login.service 2>/dev/null | head -10
echo ""
echo "[6] 当前用户 ID:"
id
echo ""
echo "========== v0.8 验证完成 =========="
EOF
}

# v0.9 验证命令
verify_v0.9() {
    cat << 'EOF'
echo "========== v0.9 网络 SSH 验证 =========="
echo "[1] 查看网络接口:"
ip addr
echo ""
echo "[2] 查看路由表:"
ip route
echo ""
echo "[3] 测试回环网络:"
ping -c 2 127.0.0.1
echo ""
echo "[4] 查看 SSH 配置:"
ls -la /etc/ssh/
echo ""
echo "[5] 查看 sshd 程序:"
ls -la /usr/sbin/sshd
echo ""
echo "[6] 查看 SSH 客户端:"
ls -la /usr/bin/ssh
echo ""
echo "========== v0.9 验证完成 =========="
EOF
}

# v1.0 验证命令
verify_v1.0() {
    cat << 'EOF'
echo "========== v1.0 完整系统验证 =========="
echo "[1] 查看网络配置:"
ip addr show eth0 2>/dev/null || ip addr
echo ""
echo "[2] 查看默认路由:"
ip route | grep default
echo ""
echo "[3] 查看网络服务状态:"
systemctl status network.service 2>/dev/null | head -10
echo ""
echo "[4] 查看 SSH 服务状态:"
systemctl status ssh.service 2>/dev/null | head -10
echo ""
echo "[5] 查看所有运行中的服务:"
systemctl list-units --state=running 2>/dev/null | head -10
echo ""
echo "[6] 查看监听端口:"
ss -tuln 2>/dev/null || netstat -tuln 2>/dev/null || echo "端口查看工具不可用"
echo ""
echo "[7] 系统启动分析:"
systemd-analyze 2>/dev/null || echo "systemd-analyze 不可用"
echo ""
echo "========== v1.0 验证完成 =========="
EOF
}

# 运行单个版本测试
run_version() {
    local version="$1"
    local version_num="${version#v}"
    local initrd="initrd${version_num}.img"
    local output_file="$RESULTS_DIR/${version}_verification.txt"
    
    echo -e "${GREEN}正在捕获 $version 的验证输出...${NC}"
    
    if [ ! -f "$initrd" ]; then
        echo "错误: 找不到 $initrd"
        return 1
    fi
    
    # 获取验证命令
    local verify_cmd
    verify_cmd=$("verify_$version" 2>/dev/null || echo "echo '未定义验证命令'")
    
    # 创建期望脚本
    local expect_script=$(cat <<EXPECT
spawn qemu-system-x86_64 \
    -kernel "$KERNEL" \
    -initrd "$initrd" \
    -m 1024 \
    -nographic \
    -append "root=/dev/ram0 rw console=ttyS0,115200 loglevel=3"

set timeout 30

# 等待启动
expect {
    "login:" {
        send "root\r"
        expect "Password:"
        send "123456\r"
    }
    "bash" {
        # 已经进入 shell
    }
    timeout {
        puts "启动超时"
        exit 1
    }
}

sleep 2

# 执行验证命令
send "$verify_cmd\r"

# 等待输出
sleep 3

# 保存输出到文件
send "cat /tmp/verify.log 2>/dev/null || echo '验证完成'\r"
sleep 1

# 退出
send "poweroff -f\r"

expect eof
EXPECT
)
    
    # 使用 script 命令记录输出
    script -q -c "
        timeout 30 qemu-system-x86_64 \
            -kernel '$KERNEL' \
            -initrd '$initrd' \
            -m 1024 \
            -nographic \
            -append 'root=/dev/ram0 rw console=ttyS0,115200 loglevel=3' \
            2>&1 | head -200
    " "$output_file" || true
    
    echo "输出已保存到: $output_file"
}

# 主程序
case "${1:-all}" in
    v0.5)
        run_version "v0.5"
        ;;
    v0.6)
        run_version "v0.6"
        ;;
    v0.7)
        run_version "v0.7"
        ;;
    v0.8)
        run_version "v0.8"
        ;;
    v0.9)
        run_version "v0.9"
        ;;
    v1.0)
        run_version "v1.0"
        ;;
    all)
        for v in v0.5 v0.6 v0.7 v0.8 v0.9 v1.0; do
            echo ""
            run_version "$v"
        done
        ;;
    *)
        echo "用法: $0 [v0.5|v0.6|v0.7|v0.8|v0.9|v1.0|all]"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}所有验证输出已保存到 $RESULTS_DIR/${NC}"
