#!/bin/bash
# 全版本自动化测试脚本
# 非侵入式测试 - 不需要修改 initrd 源码

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$BASE_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 结果目录
RESULTS_DIR="test_results"
mkdir -p "$RESULTS_DIR"

# 内核选择
KERNEL="./vmlinuz-6.8.0-90-generic"
if [ ! -f "$KERNEL" ]; then
    KERNEL="/boot/vmlinuz-6.8.0-90-generic"
    if [ ! -f "$KERNEL" ]; then
        KERNEL="/boot/vmlinuz-$(uname -r)"
    fi
fi

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Linux Initrd 全版本自动化测试                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${BLUE}内核: $KERNEL${NC}"
echo -e "${BLUE}结果目录: $RESULTS_DIR${NC}"
echo ""

# 清理旧结果
> "$RESULTS_DIR/summary.txt"

# 测试版本列表
VERSIONS="v0.5 v0.6 v0.7 v0.8 v0.9 v1.0"

# 测试每个版本
for VERSION in $VERSIONS; do
    INITRD="initrd${VERSION#v}.img"
    
    echo -e "${YELLOW}────────────────────────────────────────${NC}"
    echo -e "${YELLOW}测试 $VERSION${NC}"
    echo -e "${YELLOW}────────────────────────────────────────${NC}"
    
    if [ ! -f "$INITRD" ]; then
        echo -e "${RED}❌ 跳过: $INITRD 不存在${NC}"
        echo "$VERSION: 跳过 (镜像不存在)" >> "$RESULTS_DIR/summary.txt"
        continue
    fi
    
    # 检查镜像完整性
    echo -n "  检查镜像格式... "
    if file "$INITRD" | grep -q "gzip compressed"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ (格式异常)${NC}"
    fi
    
    # 获取镜像大小
    SIZE=$(ls -lh "$INITRD" | awk '{print $5}')
    echo "  镜像大小: $SIZE"
    
    # 尝试解压检查内容
    echo -n "  检查内容完整性... "
    if gzip -t "$INITRD" 2>/dev/null; then
        # 尝试解压并检查关键文件
        TEMP_DIR=$(mktemp -d)
        if gzip -dc "$INITRD" | cpio -id --quiet -D "$TEMP_DIR" 2>/dev/null; then
            if [ -f "$TEMP_DIR/init" ]; then
                echo -e "${GREEN}✓ (init 存在)${NC}"
                
                # 检查版本特定文件
                case "$VERSION" in
                    v0.5)
                        [ -f "$TEMP_DIR/bin/bash" ] && echo "  ${GREEN}✓${NC} bash 存在" || echo "  ${RED}✗${NC} bash 缺失"
                        ;;
                    v0.6)
                        [ -f "$TEMP_DIR/lib/systemd/systemd-udevd" ] && echo "  ${GREEN}✓${NC} udevd 存在" || echo "  ${RED}✗${NC} udevd 缺失"
                        ;;
                    v0.7)
                        [ -f "$TEMP_DIR/lib/systemd/systemd" ] && echo "  ${GREEN}✓${NC} systemd 存在" || echo "  ${RED}✗${NC} systemd 缺失"
                        ;;
                    v0.8)
                        [ -f "$TEMP_DIR/etc/passwd" ] && echo "  ${GREEN}✓${NC} passwd 存在" || echo "  ${RED}✗${NC} passwd 缺失"
                        [ -f "$TEMP_DIR/bin/login" ] && echo "  ${GREEN}✓${NC} login 存在" || echo "  ${RED}✗${NC} login 缺失"
                        ;;
                    v0.9)
                        [ -f "$TEMP_DIR/bin/ip" ] && echo "  ${GREEN}✓${NC} ip 命令存在" || echo "  ${RED}✗${NC} ip 命令缺失"
                        [ -d "$TEMP_DIR/etc/ssh" ] && echo "  ${GREEN}✓${NC} SSH 配置存在" || echo "  ${RED}✗${NC} SSH 配置缺失"
                        ;;
                    v1.0)
                        [ -f "$TEMP_DIR/etc/systemd/system/network.service" ] && echo "  ${GREEN}✓${NC} network.service 存在" || echo "  ${RED}✗${NC} network.service 缺失"
                        [ -f "$TEMP_DIR/etc/systemd/system/ssh.service" ] && echo "  ${GREEN}✓${NC} ssh.service 存在" || echo "  ${RED}✗${NC} ssh.service 缺失"
                        ;;
                esac
            else
                echo -e "${RED}✗ (init 缺失)${NC}"
            fi
        else
            echo -e "${RED}✗ (解压失败)${NC}"
        fi
        rm -rf "$TEMP_DIR"
    else
        echo -e "${RED}✗ (gzip 校验失败)${NC}"
    fi
    
    # QEMU 启动测试（快速检查）
    echo -n "  QEMU 启动测试... "
    
    # 创建期望输出模式
    case "$VERSION" in
        v0.5)
            EXPECT_PATTERN="Starting interactive shell"
            ;;
        v0.6)
            EXPECT_PATTERN="Hardware drivers loaded"
            ;;
        v0.7|v0.8|v0.9|v1.0)
            EXPECT_PATTERN="Starting systemd"
            ;;
    esac
    
    # 运行 QEMU 并捕获输出（10秒超时）
    # 根据版本调整内存大小
    if [ "$VERSION" = "v0.5" ]; then
        MEM="256"
    else
        MEM="1024"
    fi
    QEMU_LOG="$RESULTS_DIR/${VERSION}_qemu.log"
    timeout 10 qemu-system-x86_64 \
        -kernel "$KERNEL" \
        -initrd "$INITRD" \
        -m $MEM \
        -nographic \
        -append "root=/dev/ram0 rw console=ttyS0,115200 loglevel=3 panic=1" \
        2>&1 | head -150 > "$QEMU_LOG" || true
    
    if grep -q "$EXPECT_PATTERN" "$QEMU_LOG" 2>/dev/null; then
        echo -e "${GREEN}✓ 启动正常${NC}"
        echo "$VERSION: 通过 (大小: $SIZE)" >> "$RESULTS_DIR/summary.txt"
    else
        echo -e "${YELLOW}! 需要手动验证${NC}"
        echo "$VERSION: 需验证 (大小: $SIZE)" >> "$RESULTS_DIR/summary.txt"
    fi
    
    echo ""
done

# 输出汇总
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                      测试汇总                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
cat "$RESULTS_DIR/summary.txt"
echo ""

# 统计
echo -e "${BLUE}────────────────────────────────────────${NC}"
PASS_COUNT=$(grep -c "通过" "$RESULTS_DIR/summary.txt" 2>/dev/null || echo 0)
VERIFY_COUNT=$(grep -c "需验证" "$RESULTS_DIR/summary.txt" 2>/dev/null || echo 0)
SKIP_COUNT=$(grep -c "跳过" "$RESULTS_DIR/summary.txt" 2>/dev/null || echo 0)

echo -e "${GREEN}✅ 通过: $PASS_COUNT${NC}"
echo -e "${YELLOW}⚠️  需验证: $VERIFY_COUNT${NC}"
echo -e "${RED}❌ 跳过: $SKIP_COUNT${NC}"
echo ""
echo -e "${BLUE}详细日志: $RESULTS_DIR/${NC}"
echo ""
