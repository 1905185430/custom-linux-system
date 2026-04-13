# 快速 QEMU 启动指南

## 安装 QEMU（只需执行一次）

```bash
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils
```

## 快速启动命令

### 启动 v0.5（最简单版本）
```bash
qemu-system-x86_64 \
    -kernel /boot/vmlinuz-6.8.0-90-generic \
    -initrd initrd0.5.img \
    -m 512 \
    -nographic \
    -append "root=/dev/ram0 rw console=ttyS0"
```

### 启动 v1.0（完整版本）
```bash
qemu-system-x86_64 \
    -kernel /boot/vmlinuz-6.8.0-90-generic \
    -initrd initrd1.0.img \
    -m 2048 \
    -nographic \
    -append "root=/dev/ram0 rw console=ttyS0"
```

## 参数说明

| 参数 | 说明 |
|------|------|
| `-kernel` | 指定 Linux 内核 |
| `-initrd` | 指定 initrd 镜像 |
| `-m 2048` | 分配 2GB 内存 |
| `-nographic` | 无图形界面，使用终端 |
| `-append` | 传递给内核的参数 |

## 退出 QEMU

在 QEMU 终端中按：
```
Ctrl+A 然后按 X
```

## 测试检查清单

### v0.5 测试
- [ ] 能进入 bash shell
- [ ] `ls` 命令可用
- [ ] `cat /proc/version` 显示内核版本

### v0.6 测试
- [ ] 能看到 udev 启动信息
- [ ] `lsmod` 显示已加载模块
- [ ] `/dev/` 下有设备节点

### v0.7 测试
- [ ] systemd 成功启动
- [ ] `systemctl status` 显示状态
- [ ] 可以运行 systemctl 命令

### v1.0 测试
- [ ] 能登录（root，无密码）
- [ ] `ip addr` 显示网络配置
- [ ] `systemctl status ssh` 显示 SSH 运行

## 故障排除

### 如果启动卡住
添加 `debug` 参数查看详细日志：
```bash
-append "root=/dev/ram0 rw debug console=ttyS0"
```

### 如果提示找不到 init
检查 initrd 格式：
```bash
file initrd1.0.img  # 应该显示 gzip compressed
```

### 如果需要图形界面
去掉 `-nographic`，添加：
```bash
-vga std -serial stdio
```

## 一键测试脚本

保存为 `quick-test.sh`：

```bash
#!/bin/bash
VERSION=${1:-v1.0}
echo "启动 Custom Linux $VERSION..."
qemu-system-x86_64 \
    -kernel /boot/vmlinuz-6.8.0-90-generic \
    -initrd initrd${VERSION}.img \
    -m 2048 \
    -nographic \
    -append "root=/dev/ram0 rw console=ttyS0"
```

使用：
```bash
chmod +x quick-test.sh
./quick-test.sh v0.5
./quick-test.sh v1.0
```

## 常用快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+A X` | 退出 QEMU |
| `Ctrl+A C` | 进入 QEMU Monitor |
| `Ctrl+C` | 发送中断信号 |

开始测试吧！🚀
