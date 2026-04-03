#!/bin/bash
# QEMU 调试脚本 - 用于测试 initrd 镜像
# 使用方法: ./qemu-debug.sh [版本] [模式]
# 示例: ./qemu-debug.sh v0.5
#       ./qemu-debug.sh v1.0 debug

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
VERSION="${1:-v1.0}"
MODE="${2:-normal}"
KERNEL="/boot/vmlinuz-$(uname -r)"

# 显示帮助
show_help() {
    cat << EOF
QEMU 调试脚本 - 测试 Custom Linux initrd 镜像

使用方法:
    $0 [版本] [模式]

参数:
    版本: v0.5 | v0.6 | v0.7 | v1.0 (默认: v1.0)
    模式: normal | debug | nographic | serial

示例:
    $0 v0.5              # 启动 v0.5 版本
    $0 v1.0 debug        # 启动 v1.0 版本并启用调试输出
    $0 v0.6 nographic    # 无图形界面模式（纯命令行）
    $0 v0.7 serial       # 串口输出模式

模式说明:
    normal      - 图形界面模式（默认）
    debug       - 启用内核调试输出
    nographic   - 无图形界面，使用当前终端
    serial      - 输出到串口，可用于 GDB 调试
EOF
}

# 检查 QEMU
 check_qemu() {
    if ! command -v qemu-system-x86_64 &> /dev/null; then
        echo -e "${RED}错误: 未找到 QEMU${NC}"
        echo "请安装 QEMU:"
        echo "  sudo apt update"
        echo "  sudo apt install -y qemu-system-x86 qemu-utils"
        exit 1
    fi
}

# 检查内核
 check_kernel() {
    if [ ! -f "$KERNEL" ]; then
        echo -e "${RED}错误: 未找到内核文件: $KERNEL${NC}"
        echo "可用的内核:"
        ls -la /boot/vmlinuz-* 2>/dev/null || echo "  无"
        exit 1
    fi
}

# 检查 initrd
 check_initrd() {
    local initrd_file="initrd${VERSION}.img"
    if [ ! -f "$initrd_file" ]; then
        echo -e "${RED}错误: 未找到 initrd 文件: $initrd_file${NC}"
        echo "可用的 initrd 文件:"
        ls -la initrd*.img 2>/dev/null || echo "  无"
        exit 1
    fi
}

# 启动 QEMU
 start_qemu() {
    local initrd_file="initrd${VERSION}.img"
    local qemu_cmd="qemu-system-x86_64"
    
    # 基础参数
    local params="-kernel $KERNEL"
    params="$params -initrd $initrd_file"
    params="$params -m 2048"                    # 2GB 内存
    params="$params -smp 2"                     # 2个CPU核心
    params="$params -append 'root=/dev/ram0 rw console=ttyS0,115200 console=tty0'"
    
    # 根据模式添加参数
    case "$MODE" in
        normal)
            echo -e "${GREEN}启动 $VERSION 版本（图形界面模式）...${NC}"
            params="$params -vga std"
            params="$params -serial stdio"
            ;;
        debug)
            echo -e "${GREEN}启动 $VERSION 版本（调试模式）...${NC}"
            params="$params -vga std"
            params="$params -serial stdio"
            params="$params -append 'root=/dev/ram0 rw debug systemd.log_level=debug systemd.log_target=console console=ttyS0,115200 console=tty0'"
            ;;
        nographic)
            echo -e "${GREEN}启动 $VERSION 版本（无图形界面模式）...${NC}"
            params="$params -nographic"
            ;;
        serial)
            echo -e "${GREEN}启动 $VERSION 版本（串口模式）...${NC}"
            echo "串口输出将保存到 qemu-serial.log"
            params="$params -nographic"
            params="$params -serial file:qemu-serial.log"
            ;;
        *)
            echo -e "${RED}错误: 未知模式 '$MODE'${NC}"
            show_help
            exit 1
            ;;
    esac
    
    # 网络配置（可选）
    params="$params -netdev user,id=net0 -device virtio-net-pci,netdev=net0"
    
    # 显示启动信息
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} 版本: $VERSION${NC}"
    echo -e "${BLUE} 模式: $MODE${NC}"
    echo -e "${BLUE} 内核: $KERNEL${NC}"
    echo -e "${BLUE} Initrd: $initrd_file${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # 启动 QEMU
    echo "执行命令:"
    echo "$qemu_cmd $params"
    echo ""
    
    eval "$qemu_cmd $params"
}

# 主函数
main() {
    # 解析参数
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi
    
    # 检查依赖
    check_qemu
    check_kernel
    check_initrd
    
    # 启动
    start_qemu
}

# 运行主函数
main "$@"
