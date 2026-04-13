#!/bin/bash
# 自动打包指定版本的 initrd
VERSION=$1
if [ -d "initrd$VERSION" ]; then
    echo "正在打包版本 $VERSION..."
    cd "initrd$VERSION"
    find . | cpio -o -H newc | gzip > "../initrd$VERSION.img"
    cd ..
    echo "打包完成：initrd$VERSION.img"
else
    echo "错误：找不到文件夹 initrd$VERSION"
fi
