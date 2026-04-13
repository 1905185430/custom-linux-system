#!/bin/bash
# check-env.sh - 检查 QEMU 调试环境

echo "=========================================="
echo "    QEMU 调试环境检查"
echo "=========================================="
echo ""

echo "1. 检查 QEMU:"
if which qemu-system-x86_64 > /dev/null 2>&1; then
    echo "✅ QEMU 已安装"
    qemu-system-x86_64 --version | head -1
else
    echo "❌ QEMU 未安装"
    echo "   安装命令: sudo apt install -y qemu-system-x86 qemu-utils"
fi

echo ""
echo "2. 检查内核:"
if ls /boot/vmlinuz-* > /dev/null 2>&1; then
    echo "✅ 找到内核文件:"
    ls -la /boot/vmlinuz-* | awk '{print "   " $9, "(" $5 ")"}'
else
    echo "❌ 未找到内核文件"
fi

echo ""
echo "3. 检查 initrd 镜像:"
if ls initrd*.img > /dev/null 2>&1; then
    echo "✅ 找到 initrd 镜像:"
    ls -la initrd*.img | awk '{print "   " $9, "(" $5 ")"}'
else
    echo "❌ 未找到 initrd 镜像"
fi

echo ""
echo "4. 检查内存:"
echo "   系统内存:"
free -h | grep "Mem:"

echo ""
echo "5. 检查磁盘空间:"
echo "   当前目录可用空间:"
df -h . | tail -1 | awk '{print "   " $4 " 可用 / " $2 " 总计"}'

echo ""
echo "=========================================="
echo "检查完成！"
echo ""

# 如果 QEMU 已安装，显示使用提示
if which qemu-system-x86_64 > /dev/null 2>&1; then
    echo "💡 快速启动命令:"
    echo "   ./qemu-debug.sh v1.0"
    echo ""
    echo "💡 查看详细指南:"
    echo "   cat QEMU_DEBUG_GUIDE.md"
fi
