#!/bin/bash
# make-usb-boot.sh - 制作 USB 启动盘脚本
# 适用于 v1.0 完整系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认配置
USB_DEVICE=""
MOUNT_POINT="/mnt/usb"
INITRD_FILE="boot/initrd1.0.img"
KERNEL_VERSION="6.8.0-90-generic"

# 显示帮助
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] <device>

制作 Custom Linux v1.0 USB 启动盘

参数:
    device          USB 设备路径 (例如: /dev/sdb)

选项:
    -h, --help      显示帮助信息
    -k, --kernel    指定内核版本 (默认: ${KERNEL_VERSION})
    -i, --initrd    指定 initrd 文件路径 (默认: ${INITRD_FILE})
    -m, --mount     指定挂载点 (默认: ${MOUNT_POINT})
    -y, --yes       自动确认，不提示

示例:
    $0 /dev/sdb
    $0 -k 6.8.0-90-generic -i boot/initrd1.0.img /dev/sdc
    $0 --yes /dev/sdb

警告:
    此操作会清空 USB 设备上的所有数据！
    请确保选择了正确的设备！
EOF
}

# 检查 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}错误: 请使用 sudo 运行此脚本${NC}"
        exit 1
    fi
}

# 检查依赖
check_dependencies() {
    local deps="parted mkfs.fat grub-install mount umount"
    for dep in $deps; do
        if ! command -v $dep &> /dev/null; then
            echo -e "${RED}错误: 未找到 $dep，请安装相应软件包${NC}"
            exit 1
        fi
    done
}

# 确认设备
confirm_device() {
    echo -e "${YELLOW}警告: 这将清空 ${USB_DEVICE} 上的所有数据！${NC}"
    echo "设备信息:"
    lsblk $USB_DEVICE 2>/dev/null || true
    fdisk -l $USB_DEVICE 2>/dev/null | head -5 || true
    
    if [ "$AUTO_YES" != "true" ]; then
        read -p "是否继续? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "已取消"
            exit 0
        fi
    fi
}

# 卸载设备
unmount_device() {
    echo "卸载设备..."
    umount ${USB_DEVICE}* 2>/dev/null || true
    umount $MOUNT_POINT 2>/dev/null || true
}

# 创建分区表
create_partition() {
    echo -e "${GREEN}创建 MBR 分区表...${NC}"
    parted $USB_DEVICE mklabel msdos
    
    echo -e "${GREEN}创建 FAT32 分区...${NC}"
    parted $USB_DEVICE mkpart primary fat32 1MiB 100%
    parted $USB_DEVICE set 1 boot on
    
    # 等待分区创建
    sleep 2
    partprobe $USB_DEVICE 2>/dev/null || true
}

# 格式化分区
format_partition() {
    echo -e "${GREEN}格式化分区...${NC}"
    mkfs.fat -F32 ${USB_DEVICE}1
}

# 挂载分区
mount_partition() {
    echo -e "${GREEN}挂载分区...${NC}"
    mkdir -p $MOUNT_POINT
    mount ${USB_DEVICE}1 $MOUNT_POINT
}

# 安装 GRUB
install_grub() {
    echo -e "${GREEN}安装 GRUB...${NC}"
    grub-install --target=i386-pc --recheck --boot-directory=$MOUNT_POINT/boot $USB_DEVICE
}

# 复制系统文件
copy_files() {
    echo -e "${GREEN}复制系统文件...${NC}"
    
    # 检查 initrd 文件
    if [ ! -f "$INITRD_FILE" ]; then
        echo -e "${RED}错误: 找不到 initrd 文件: $INITRD_FILE${NC}"
        exit 1
    fi
    
    # 检查内核文件
    KERNEL_FILE="/boot/vmlinuz-${KERNEL_VERSION}"
    if [ ! -f "$KERNEL_FILE" ]; then
        echo -e "${RED}错误: 找不到内核文件: $KERNEL_FILE${NC}"
        echo "可用的内核:"
        ls /boot/vmlinuz-* 2>/dev/null || true
        exit 1
    fi
    
    mkdir -p $MOUNT_POINT/boot
    cp $INITRD_FILE $MOUNT_POINT/boot/
    cp $KERNEL_FILE $MOUNT_POINT/boot/
    
    echo "已复制:"
    ls -lh $MOUNT_POINT/boot/
}

# 创建 GRUB 配置
create_grub_config() {
    echo -e "${GREEN}创建 GRUB 配置...${NC}"
    
    mkdir -p $MOUNT_POINT/boot/grub
    
    cat > $MOUNT_POINT/boot/grub/grub.cfg << EOF
set timeout=5
set default=0

# 设置分辨率
set gfxmode=auto

menuentry "Custom Linux v1.0 (Full System)" {
    echo "Loading kernel..."
    linux /boot/vmlinuz-${KERNEL_VERSION} root=/dev/ram0 rw
    echo "Loading initrd..."
    initrd /boot/initrd1.0.img
    echo "Booting..."
}

menuentry "Custom Linux v1.0 (Debug Mode)" {
    echo "Loading kernel..."
    linux /boot/vmlinuz-${KERNEL_VERSION} root=/dev/ram0 rw debug systemd.log_level=debug systemd.log_target=console
    echo "Loading initrd..."
    initrd /boot/initrd1.0.img
    echo "Booting..."
}

menuentry "Custom Linux v1.0 (Single User)" {
    echo "Loading kernel..."
    linux /boot/vmlinuz-${KERNEL_VERSION} root=/dev/ram0 rw single
    echo "Loading initrd..."
    initrd /boot/initrd1.0.img
    echo "Booting..."
}

menuentry "System Information" {
    echo "Custom Linux v1.0"
    echo "Kernel: ${KERNEL_VERSION}"
    echo "Initrd: initrd1.0.img"
    echo ""
    echo "Press ESC to return"
    sleep 60
}
EOF
}

# 清理和卸载
cleanup() {
    echo -e "${GREEN}清理...${NC}"
    sync
    umount $MOUNT_POINT 2>/dev/null || true
    rm -rf $MOUNT_POINT 2>/dev/null || true
    partprobe $USB_DEVICE 2>/dev/null || true
}

# 显示完成信息
show_completion() {
    echo ""
    echo -e "${GREEN}=================================${NC}"
    echo -e "${GREEN}USB 启动盘制作完成！${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo ""
    echo "设备: $USB_DEVICE"
    echo "分区: ${USB_DEVICE}1"
    echo ""
    echo "启动方法:"
    echo "1. 将 USB 设备插入目标计算机"
    echo "2. 进入 BIOS/UEFI 设置"
    echo "3. 选择 USB 设备启动"
    echo "4. 在 GRUB 菜单选择启动项"
    echo ""
    echo "网络配置:"
    echo "  IP: 192.168.1.100/24"
    echo "  网关: 192.168.1.1"
    echo ""
    echo "SSH 登录:"
    echo "  ssh root@192.168.1.100"
    echo ""
    echo -e "${YELLOW}注意: 请安全移除 USB 设备${NC}"
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -k|--kernel)
                KERNEL_VERSION="$2"
                shift 2
                ;;
            -i|--initrd)
                INITRD_FILE="$2"
                shift 2
                ;;
            -m|--mount)
                MOUNT_POINT="$2"
                shift 2
                ;;
            -y|--yes)
                AUTO_YES="true"
                shift
                ;;
            -*)
                echo -e "${RED}错误: 未知选项 $1${NC}"
                show_help
                exit 1
                ;;
            *)
                USB_DEVICE="$1"
                shift
                ;;
        esac
    done
    
    # 检查设备参数
    if [ -z "$USB_DEVICE" ]; then
        echo -e "${RED}错误: 请指定 USB 设备${NC}"
        show_help
        exit 1
    fi
    
    # 检查设备是否存在
    if [ ! -b "$USB_DEVICE" ]; then
        echo -e "${RED}错误: 设备 $USB_DEVICE 不存在${NC}"
        echo "可用设备:"
        lsblk -d -o NAME,SIZE,TYPE | grep disk || true
        exit 1
    fi
    
    # 检查是否是系统磁盘
    if mount | grep -q "^$USB_DEVICE"; then
        echo -e "${RED}错误: $USB_DEVICE 是系统磁盘或已挂载${NC}"
        exit 1
    fi
    
    # 执行步骤
    check_root
    check_dependencies
    confirm_device
    unmount_device
    create_partition
    format_partition
    mount_partition
    install_grub
    copy_files
    create_grub_config
    cleanup
    show_completion
}

# 运行主函数
main "$@"
