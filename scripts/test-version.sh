#!/bin/bash
# 自动化测试脚本 - 测试指定版本的 initrd
# 用法: ./test-version.sh <版本> [超时秒数]

set -e

VERSION="${1:-v1.0}"
TIMEOUT="${2:-30}"
INITRD="initrd${VERSION}.img"
KERNEL="./vmlinuz-6.8.0-90-generic"
RESULTS_DIR="test_results"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 创建结果目录
mkdir -p "$RESULTS_DIR"

# 检查文件
if [ ! -f "$INITRD" ]; then
    echo -e "${RED}❌ 错误: 找不到 $INITRD${NC}"
    exit 1
fi

if [ ! -f "$KERNEL" ]; then
    # 尝试使用系统内核
    KERNEL="/boot/vmlinuz-6.8.0-90-generic"
    if [ ! -f "$KERNEL" ]; then
        KERNEL="/boot/vmlinuz-$(uname -r)"
    fi
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  测试版本: $VERSION${NC}"
echo -e "${BLUE}  内核: $KERNEL${NC}"
echo -e "${BLUE}  Initrd: $INITRD${NC}"
echo -e "${BLUE}  超时: ${TIMEOUT}秒${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 测试日志文件
TEST_LOG="$RESULTS_DIR/${VERSION}.log"
SUMMARY_FILE="$RESULTS_DIR/summary.txt"

# 根据版本定义测试命令
case "$VERSION" in
    v0.5)
        TEST_COMMANDS='
echo "[TEST] 检查基础命令..."
ls -la / > /dev/null && echo "[PASS] ls 命令正常"
cat /proc/version > /dev/null && echo "[PASS] cat 命令正常"
echo "[TEST] 检查挂载..."
mount | grep -q proc && echo "[PASS] proc 已挂载"
mount | grep -q sysfs && echo "[PASS] sysfs 已挂载"
echo "[TEST] v0.5 测试完成"
'
        ;;
    v0.6)
        TEST_COMMANDS='
echo "[TEST] 检查 udev..."
ps | grep -q udevd && echo "[PASS] udevd 运行中"
lsmod > /dev/null 2>&1 && echo "[PASS] lsmod 可用"
ls /dev/ | grep -q tty && echo "[PASS] 设备节点存在"
echo "[TEST] v0.6 测试完成"
'
        ;;
    v0.7)
        TEST_COMMANDS='
echo "[TEST] 检查 systemd..."
ps -p 1 | grep -q systemd && echo "[PASS] systemd 是 PID 1"
systemctl status > /dev/null 2>&1 && echo "[PASS] systemctl 可用"
echo "[TEST] v0.7 测试完成"
'
        ;;
    v0.8)
        TEST_COMMANDS='
echo "[TEST] 检查登录系统..."
cat /etc/passwd | grep -q root && echo "[PASS] passwd 文件存在"
cat /etc/shadow | grep -q root && echo "[PASS] shadow 文件存在"
ls /etc/pam.d/ > /dev/null && echo "[PASS] PAM 配置存在"
echo "[TEST] v0.8 测试完成"
'
        ;;
    v0.9)
        TEST_COMMANDS='
echo "[TEST] 检查网络..."
ip addr > /dev/null 2>&1 && echo "[PASS] ip 命令可用"
ping -c 1 127.0.0.1 > /dev/null 2>&1 && echo "[PASS] ping 可用"
ls /etc/ssh/ > /dev/null && echo "[PASS] SSH 配置存在"
echo "[TEST] v0.9 测试完成"
'
        ;;
    v1.0)
        TEST_COMMANDS='
echo "[TEST] 检查网络服务..."
ip addr | grep -q eth0 && echo "[PASS] eth0 接口存在"
systemctl status network.service > /dev/null 2>&1 && echo "[PASS] network 服务运行"
echo "[TEST] 检查 SSH 服务..."
systemctl status ssh.service > /dev/null 2>&1 && echo "[PASS] ssh 服务运行"
echo "[TEST] v1.0 测试完成"
'
        ;;
    *)
        echo -e "${RED}❌ 未知版本: $VERSION${NC}"
        exit 1
        ;;
esac

# 创建测试脚本
TEST_SCRIPT=$(cat <<EOF
#!/bin/bash
# 测试脚本
$TEST_COMMANDS
# 关闭 QEMU
poweroff -f
EOF
)

# 写入临时文件
echo "$TEST_SCRIPT" > /tmp/test_${VERSION}.sh
chmod +x /tmp/test_${VERSION}.sh

# 创建 initrd 的测试版本
echo -e "${YELLOW}🔨 准备测试镜像...${NC}"
cd "initrd${VERSION}"
cp /tmp/test_${VERSION}.sh test.sh
chmod +x test.sh

# 修改 init 脚本以运行测试
cat > init.test << 'INITEOF'
#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
echo "[TEST] 启动测试环境..."
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
INITEOF

# 根据版本添加特定启动逻辑
case "$VERSION" in
    v0.5)
        cat >> init.test << 'INITEOF'
/test.sh 2>&1 | tee /test.log
exec /bin/bash
INITEOF
        ;;
    v0.6)
        cat >> init.test << 'INITEOF'
/lib/systemd/systemd-udevd --daemon
/bin/udevadm trigger --action=add
/bin/udevadm settle
/test.sh 2>&1 | tee /test.log
exec /bin/bash
INITEOF
        ;;
    v0.7|v0.8|v0.9|v1.0)
        cat >> init.test << 'INITEOF'
/lib/systemd/systemd-udevd --daemon
/bin/udevadm trigger --action=add
/bin/udevadm settle
echo "[TEST] 启动 systemd..."
ln -sf /lib/systemd/systemd /sbin/init 2>/dev/null || true
# 创建测试服务
cat > /etc/systemd/system/test.service << 'SVCEOF'
[Unit]
Description=Test Service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/test.sh
StandardOutput=file:/test.log
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF
ln -sf /etc/systemd/system/test.service /etc/systemd/system/multi-user.target.wants/
exec /lib/systemd/systemd
INITEOF
        ;;
esac

chmod +x init.test

# 打包测试镜像
echo -e "${YELLOW}📦 打包测试镜像...${NC}"
find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > "../$RESULTS_DIR/initrd${VERSION}-test.img"
cd ..

# 运行 QEMU 测试
echo -e "${YELLOW}🚀 启动 QEMU 测试...${NC}"
echo ""

# 使用 timeout 运行 QEMU
timeout $TIMEOUT qemu-system-x86_64 \
    -kernel "$KERNEL" \
    -initrd "$RESULTS_DIR/initrd${VERSION}-test.img" \
    -m 512 \
    -nographic \
    -append "root=/dev/ram0 rw console=ttyS0,115200 loglevel=3 quiet" \
    2>&1 | tee "$TEST_LOG" || true

# 分析测试结果
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  测试结果分析${NC}"
echo -e "${BLUE}========================================${NC}"

# 统计通过/失败
PASS_COUNT=$(grep -c "\[PASS\]" "$TEST_LOG" 2>/dev/null || echo 0)
FAIL_COUNT=$(grep -c "\[FAIL\]" "$TEST_LOG" 2>/dev/null || echo 0)

echo -e "${GREEN}✅ 通过: $PASS_COUNT${NC}"
echo -e "${RED}❌ 失败: $FAIL_COUNT${NC}"

# 显示详细结果
echo ""
echo "详细结果:"
grep -E "\[(PASS|FAIL)\]" "$TEST_LOG" 2>/dev/null || echo "未找到测试结果标记"

# 写入汇总
TEST_STATUS="通过"
if [ "$FAIL_COUNT" -gt 0 ]; then
    TEST_STATUS="失败"
elif [ "$PASS_COUNT" -eq 0 ]; then
    TEST_STATUS="未知"
fi

echo "$VERSION: $TEST_STATUS (通过: $PASS_COUNT, 失败: $FAIL_COUNT)" >> "$SUMMARY_FILE"

echo ""
echo -e "${BLUE}测试日志: $TEST_LOG${NC}"
echo -e "${BLUE}测试镜像: $RESULTS_DIR/initrd${VERSION}-test.img${NC}"

# 返回结果
if [ "$TEST_STATUS" = "通过" ]; then
    exit 0
else
    exit 1
fi
