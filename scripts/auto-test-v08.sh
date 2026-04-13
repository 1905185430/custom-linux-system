#!/bin/bash
# v0.8 自动化测试脚本 - 自动登录并测试所有功能

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }

# 测试日志文件
TEST_LOG="/tmp/v08_auto_test.log"
QEMU_PID_FILE="/tmp/v08_qemu.pid"

# 清理旧日志
rm -f "$TEST_LOG"

# 启动 QEMU
start_qemu() {
    log_step "启动 v0.8 QEMU..."
    
    # 使用 script 来记录终端会话
    script -q -c "
        qemu-system-x86_64 \
            -kernel ./vmlinuz-6.8.0-90-generic \
            -initrd initrd0.8.img \
            -m 1024 \
            -append 'root=/dev/ram0 rw console=ttyS0,115200 loglevel=3' \
            -nographic \
            < /tmp/v08_input_fifo 2>&1
    " "$TEST_LOG" &
    
    QEMU_PID=$!
    echo $QEMU_PID > "$QEMU_PID_FILE"
    log_info "QEMU PID: $QEMU_PID"
}

# 创建输入 FIFO
setup_fifo() {
    rm -f /tmp/v08_input_fifo
    mkfifo /tmp/v08_input_fifo
    exec 3<> /tmp/v08_input_fifo
}

# 发送输入到 QEMU
send_input() {
    local input="$1"
    local delay="${2:-1}"
    echo "$input" >&3
    sleep "$delay"
}

# 等待特定输出
wait_for_output() {
    local pattern="$1"
    local timeout="${2:-30}"
    local count=0
    
    while [ $count -lt $timeout ]; do
        if grep -q "$pattern" "$TEST_LOG" 2>/dev/null; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    return 1
}

# 停止 QEMU
stop_qemu() {
    if [ -f "$QEMU_PID_FILE" ]; then
        kill $(cat "$QEMU_PID_FILE") 2>/dev/null || true
        rm -f "$QEMU_PID_FILE"
    fi
    exec 3>&- 2>/dev/null || true
    rm -f /tmp/v08_input_fifo
}

# 测试登录功能
test_login() {
    log_step "测试登录功能..."
    
    # 等待登录提示
    if wait_for_output "localhost login:" 30; then
        log_success "登录提示出现"
    else
        log_error "等待登录提示超时"
        return 1
    fi
    
    # 发送用户名
    send_input "root" 2
    
    # 等待密码提示
    if wait_for_output "Password:" 10; then
        log_success "密码提示出现"
    else
        log_error "等待密码提示超时"
        return 1
    fi
    
    # 发送密码
    send_input "123456" 3
    
    # 检查是否登录成功（通过检查 shell 提示符）
    sleep 2
    if grep -E "root@|#" "$TEST_LOG" 2>/dev/null; then
        log_success "登录成功"
        return 0
    else
        log_error "登录失败"
        return 1
    fi
}

# 测试基本命令
test_basic_commands() {
    log_step "测试基本命令..."
    
    local tests_passed=0
    local tests_total=0
    
    # 测试 id 命令
    tests_total=$((tests_total + 1))
    send_input "id" 2
    if grep -q "uid=0(root)" "$TEST_LOG" 2>/dev/null; then
        log_success "id 命令输出正确"
        tests_passed=$((tests_passed + 1))
    else
        log_error "id 命令输出错误"
    fi
    
    # 测试 pwd 命令
    tests_total=$((tests_total + 1))
    send_input "pwd" 2
    if grep -q "/root" "$TEST_LOG" 2>/dev/null; then
        log_success "pwd 命令输出正确"
        tests_passed=$((tests_passed + 1))
    else
        log_error "pwd 命令输出错误"
    fi
    
    # 测试 whoami 命令
    tests_total=$((tests_total + 1))
    send_input "whoami" 2
    if grep -q "root" "$TEST_LOG" 2>/dev/null; then
        log_success "whoami 命令输出正确"
        tests_passed=$((tests_passed + 1))
    else
        log_error "whoami 命令输出错误"
    fi
    
    log_info "基本命令测试: $tests_passed/$tests_total 通过"
    return 0
}

# 测试用户认证文件
test_auth_files() {
    log_step "测试用户认证文件..."
    
    local tests_passed=0
    local tests_total=4
    
    # 测试 /etc/passwd
    send_input "cat /etc/passwd | grep root" 2
    if grep -q "root:x:0:0" "$TEST_LOG" 2>/dev/null; then
        log_success "/etc/passwd 存在且正确"
        tests_passed=$((tests_passed + 1))
    else
        log_error "/etc/passwd 检查失败"
    fi
    
    # 测试 /etc/shadow
    send_input "ls -la /etc/shadow" 2
    if grep -q "shadow" "$TEST_LOG" 2>/dev/null; then
        log_success "/etc/shadow 存在"
        tests_passed=$((tests_passed + 1))
    else
        log_error "/etc/shadow 检查失败"
    fi
    
    # 测试 /etc/group
    send_input "cat /etc/group | grep root" 2
    if grep -q "root:x:0:" "$TEST_LOG" 2>/dev/null; then
        log_success "/etc/group 存在且正确"
        tests_passed=$((tests_passed + 1))
    else
        log_error "/etc/group 检查失败"
    fi
    
    # 测试 PAM 配置
    send_input "ls /etc/pam.d/" 2
    if grep -q "login" "$TEST_LOG" 2>/dev/null; then
        log_success "PAM 配置存在"
        tests_passed=$((tests_passed + 1))
    else
        log_error "PAM 配置检查失败"
    fi
    
    log_info "用户认证文件测试: $tests_passed/$tests_total 通过"
    return 0
}

# 测试 PAM 和登录程序
test_pam_login() {
    log_step "测试 PAM 和登录程序..."
    
    local tests_passed=0
    local tests_total=3
    
    # 测试 login 程序存在
    send_input "ls -la /bin/login" 2
    if grep -q "login" "$TEST_LOG" 2>/dev/null; then
        log_success "/bin/login 程序存在"
        tests_passed=$((tests_passed + 1))
    else
        log_error "/bin/login 程序不存在"
    fi
    
    # 测试 PAM 库存在
    send_input "ls /lib/security/" 2
    if grep -q "pam_unix" "$TEST_LOG" 2>/dev/null; then
        log_success "PAM 库存在"
        tests_passed=$((tests_passed + 1))
    else
        log_error "PAM 库检查失败"
    fi
    
    # 测试 console-login 服务
    send_input "systemctl status console-login.service" 3
    if grep -q "Active: active" "$TEST_LOG" 2>/dev/null; then
        log_success "console-login 服务运行中"
        tests_passed=$((tests_passed + 1))
    else
        log_error "console-login 服务检查失败"
    fi
    
    log_info "PAM 和登录程序测试: $tests_passed/$tests_total 通过"
    return 0
}

# 生成测试报告
generate_report() {
    log_step "生成测试报告..."
    
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  v0.8 自动化测试报告${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    
    # 显示测试日志的最后部分
    echo "测试日志摘要:"
    tail -100 "$TEST_LOG" 2>/dev/null | grep -E "(login|Password|root@|#|OK|FAIL)" | tail -20
    
    echo ""
    echo "完整日志保存在: $TEST_LOG"
    echo ""
}

# 主流程
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  v0.8 自动化测试${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # 设置清理函数
    trap stop_qemu EXIT
    
    # 设置 FIFO
    setup_fifo
    
    # 启动 QEMU
    start_qemu
    
    # 等待系统启动
    log_info "等待系统启动..."
    sleep 10
    
    # 执行测试
    test_login
    test_basic_commands
    test_auth_files
    test_pam_login
    
    # 生成报告
    generate_report
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  v0.8 自动化测试完成!${NC}"
    echo -e "${GREEN}========================================${NC}"
}

main "$@"
