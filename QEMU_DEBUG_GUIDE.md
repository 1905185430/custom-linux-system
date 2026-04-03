# QEMU 调试指南

## 安装 QEMU

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils
```

### 验证安装
```bash
qemu-system-x86_64 --version
```

## 快速开始

### 1. 使用调试脚本（推荐）

```bash
# 启动 v1.0 版本（图形界面）
./qemu-debug.sh v1.0

# 启动 v0.5 版本（调试模式）
./qemu-debug.sh v0.5 debug

# 启动 v0.6 版本（无图形界面）
./qemu-debug.sh v0.6 nographic

# 查看帮助
./qemu-debug.sh --help
```

### 2. 手动启动 QEMU

#### 基础启动
```bash
qemu-system-x86_64 \
    -kernel /boot/vmlinuz-$(uname -r) \
    -initrd initrd1.0.img \
    -m 2048 \
    -smp 2 \
    -append "root=/dev/ram0 rw console=ttyS0,115200" \
    -serial stdio \
    -vga std
```

#### 调试模式
```bash
qemu-system-x86_64 \
    -kernel /boot/vmlinuz-$(uname -r) \
    -initrd initrd1.0.img \
    -m 2048 \
    -append "root=/dev/ram0 rw debug systemd.log_level=debug" \
    -serial stdio \
    -nographic
```

## 调试技巧

### 1. 查看启动日志

```bash
# 保存启动日志到文件
qemu-system-x86_64 \
    -kernel /boot/vmlinuz-$(uname -r) \
    -initrd initrd1.0.img \
    -m 2048 \
    -append "root=/dev/ram0 rw" \
    -serial file:boot.log \
    -nographic

# 查看日志
tail -f boot.log
```

### 2. 使用 GDB 调试内核

#### 启动 QEMU 并等待 GDB 连接
```bash
qemu-system-x86_64 \
    -kernel /boot/vmlinuz-$(uname -r) \
    -initrd initrd1.0.img \
    -m 2048 \
    -append "root=/dev/ram0 rw nokaslr" \
    -s -S \
    -nographic
```

参数说明：
- `-s`: 在端口 1234 启动 GDB 服务器
- `-S`: 启动时暂停 CPU，等待 GDB 连接
- `nokaslr`: 禁用内核地址空间随机化

#### 在另一个终端连接 GDB
```bash
# 安装 gdb
gdb /boot/vmlinuz-$(uname -r)

# 在 GDB 中连接 QEMU
(gdb) target remote localhost:1234

# 设置断点
(gdb) break start_kernel

# 继续执行
(gdb) continue

# 查看调用栈
(gdb) backtrace

# 查看寄存器
(gdb) info registers

# 单步执行
(gdb) step
(gdb) next
```

### 3. 网络调试

#### 配置用户模式网络
```bash
qemu-system-x86_64 \
    -kernel /boot/vmlinuz-$(uname -r) \
    -initrd initrd1.0.img \
    -m 2048 \
    -append "root=/dev/ram0 rw" \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=net0 \
    -nographic
```

从宿主机 SSH 连接到 QEMU：
```bash
ssh -p 2222 root@localhost
```

### 4. 挂载磁盘镜像

如果需要测试磁盘操作：

```bash
# 创建磁盘镜像
qemu-img create -f raw test-disk.img 1G

# 格式化
mkfs.ext4 test-disk.img

# 启动时挂载
qemu-system-x86_64 \
    -kernel /boot/vmlinuz-$(uname -r) \
    -initrd initrd1.0.img \
    -m 2048 \
    -drive file=test-disk.img,format=raw,index=0,media=disk \
    -append "root=/dev/ram0 rw" \
    -nographic
```

## 各版本测试要点

### v0.5 - 基础版本
测试内容：
- 基础命令是否可用
- 文件系统挂载
- shell 交互

```bash
./qemu-debug.sh v0.5

# 在 QEMU 中测试
ls -la /
cat /proc/version
mount
```

### v0.6 - udev 版本
测试内容：
- 硬件自动检测
- 驱动模块加载
- 设备节点创建

```bash
./qemu-debug.sh v0.6 debug

# 在 QEMU 中测试
lsmod
ls -la /dev/
udevadm info --env
```

### v0.7 - systemd 版本
测试内容：
- systemd 启动
- 服务管理
- target 运行

```bash
./qemu-debug.sh v0.7

# 在 QEMU 中测试
systemctl status
systemctl list-units
journalctl
```

### v1.0 - 完整版本
测试内容：
- 用户登录
- 网络配置
- SSH 服务

```bash
./qemu-debug.sh v1.0

# 在 QEMU 中测试
ip addr
ip route
systemctl status ssh
ss -tuln
```

## 常见问题

### 1. 启动卡住

**问题**: 启动过程中卡住不动

**解决**:
```bash
# 添加详细日志
-append "root=/dev/ram0 rw debug ignore_loglevel"

# 或检查 init 脚本
-append "root=/dev/ram0 rw init=/bin/bash"
```

### 2. 内核 panic

**问题**: 出现 kernel panic

**解决**:
```bash
# 检查内核版本匹配
uname -r

# 使用正确的内核
qemu-system-x86_64 \
    -kernel /boot/vmlinuz-6.8.0-90-generic \
    -initrd initrd1.0.img \
    ...
```

### 3. 无法识别 initrd

**问题**: 提示无法找到 init

**解决**:
```bash
# 检查 initrd 格式
file initrd1.0.img

# 应该是: gzip compressed data

# 解压检查内容
cd /tmp
gunzip -c /path/to/initrd1.0.img | cpio -idmv
ls -la
```

### 4. 内存不足

**问题**: 系统运行缓慢或 OOM

**解决**:
```bash
# 增加内存
-m 4096  # 4GB

# 或减少内存使用（对于小版本）
-m 512   # 512MB 对于 v0.5 足够
```

## 高级调试

### 1. 内核调试配置

创建 `.gdbinit` 文件：
```bash
cat > ~/.gdbinit <> 'EOF'
set architecture i386:x86-64
set disassembly-flavor intel
set print pretty on
set pagination off

# 常用命令别名
define kbt
    backtrace
end

define kregs
    info registers
end

define kstack
    x/32xg $sp
end
EOF
```

### 2. 使用 QEMU Monitor

在 QEMU 运行时，按 `Ctrl+A` 然后按 `C` 进入 monitor：

```
(qemu) info registers          # 查看寄存器
(qemu) info cpus               # 查看 CPU 信息
(qemu) x/10i $pc              # 查看指令
(qemu) memsave 0x1000000 4096 mem.bin  # 保存内存
(qemu) system_reset           # 重启系统
(qemu) quit                   # 退出 QEMU
```

### 3. 性能分析

```bash
# 启用性能分析
qemu-system-x86_64 \
    -kernel /boot/vmlinuz-$(uname -r) \
    -initrd initrd1.0.img \
    -m 2048 \
    -append "root=/dev/ram0 rw" \
    -trace events=/tmp/events \
    -nographic
```

## 调试检查清单

- [ ] QEMU 已安装
- [ ] 内核文件存在 (/boot/vmlinuz-*)
- [ ] initrd 镜像存在
- [ ] 内存分配足够 (-m 2048)
- [ ] 内核版本匹配
- [ ] initrd 格式正确 (gzip + cpio)

## 有用的快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+A` `C` | 切换到 QEMU Monitor |
| `Ctrl+A` `X` | 退出 QEMU |
| `Ctrl+A` `S` | 保存虚拟机状态 |
| `Ctrl+C` | 发送中断信号 |

## 参考资源

- QEMU 文档: https://qemu.readthedocs.io/
- Linux 内核调试: https://www.kernel.org/doc/html/latest/dev-tools/gdb-kernel-debugging.html
- GDB 手册: https://sourceware.org/gdb/current/onlinedocs/gdb/

## 故障排除脚本

创建一个检查脚本：

```bash
#!/bin/bash
# check-env.sh - 检查调试环境

echo "=== QEMU 调试环境检查 ==="
echo ""

echo "1. 检查 QEMU:"
which qemu-system-x86_64 && qemu-system-x86_64 --version || echo "❌ QEMU 未安装"

echo ""
echo "2. 检查内核:"
ls -la /boot/vmlinuz-*

echo ""
echo "3. 检查 initrd 镜像:"
ls -la initrd*.img 2>/dev/null || echo "❌ 未找到 initrd 镜像"

echo ""
echo "4. 检查内存:"
free -h

echo ""
echo "5. 检查磁盘空间:"
df -h .

echo ""
echo "=== 检查完成 ==="
```

祝您调试顺利！🐛🔧
