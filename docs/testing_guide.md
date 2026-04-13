# Linux Initrd v0.5 - v1.0 启动与测试指南

这份指南汇总了每一个 initrd 版本的正确 QEMU 测试启动命令，以及进入系统后用来验证该版本专属功能的常用命令。

> [!IMPORTANT]
> 串口模式建议统一使用：`console=ttyS0,115200 loglevel=3 systemd.show_status=false`。
> 这样可显著减少 systemd 状态刷屏与登录提示互相打断导致的乱码。

> [!TIP]
> **退出 QEMU 提示**：由于我们使用了 `-nographic` 终端模式运行。当您在虚拟机（QEMU 内部）测试完毕想要退出并关闭虚拟机时，请按下 `Ctrl + A` 组合键，松开后再按 `X` 键即可退出虚拟机。

---

## [v0.5] 基础环境测试

此版本是最迷你的小系统，用于验证最基础的 Linux 接口能否运行。

**启动命令：**
```bash
qemu-system-x86_64 -kernel ./vmlinuz-6.8.0-90-generic -initrd initrd0.5.img -m 512 -cpu host -enable-kvm -append "root=/dev/ram0 rw console=ttyS0,115200 loglevel=3 systemd.show_status=false panic=5" -nographic
```

**虚拟机内测试指令：**
```bash
# 1. 测试虚拟文件系统挂载
mount
# 2. 测试通过 ldd 转移的核心基本命令
ls -l /
mkdir /test_dir
cp /init /test_dir/
cat /test_dir/init
# 3. 查看当前正在运行的基本进程
ps
```

---

## [v0.6] 硬件检测驱动 (Udev)

该版本引入了 `systemd-udevd`，核心是对宿主的底层基础硬件进行动态识别。

**启动命令：**
```bash
qemu-system-x86_64 -kernel ./vmlinuz-6.8.0-90-generic -initrd initrd0.6.img -m 512 -cpu host -enable-kvm -append "root=/dev/ram0 rw console=ttyS0,115200 loglevel=3 systemd.show_status=false panic=5" -nographic
```

**虚拟机内测试指令：**
```bash
# 1. 查看 udev 在 init 阶段为我们自动加载了哪些被打包进来的内核驱动
lsmod
# 2. 确认 udev 守护进程处于运行待命状态
ps | grep udevd
# 3. 检查 /dev 目录下是否由 udev 成功映射出了块设备或控制台设备
ls -l /dev | grep -E "tty|sda"
```

---

## [v0.7] 初始化接管 (Systemd)

系统初始进程正式由简单的 `bash/sh` 更迭为现代化的 `systemd`，负责目标环境和服务的调度。

**启动命令：**
```bash
qemu-system-x86_64 -kernel ./vmlinuz-6.8.0-90-generic -initrd initrd0.7.img -m 512 -cpu host -enable-kvm -append "root=/dev/ram0 rw console=ttyS0,115200 loglevel=3 systemd.show_status=false panic=5" -nographic
```

**虚拟机内测试指令：**
```bash
# 1. 验证 1 号进程已被 systemd 成功掌管
ps -p 1
# 2. 纵览当前的所有 systemd 挂载 target 与 unit 运行状态
systemctl status
# 3. 查看我们在脚本中为其临时补充的交互控制台服务
systemctl status bash.service
```

---

## [v0.8] 用户分级隔离

测试系统现在拥有了账号身份与对应凭证（`passwd`、`shadow` 以及 `PAM` 认证），具备防御越权机制。

**启动命令：**
```bash
qemu-system-x86_64 -kernel ./vmlinuz-6.8.0-90-generic -initrd initrd0.8.img -m 512 -cpu host -enable-kvm -append "root=/dev/ram0 rw console=ttyS0,115200 loglevel=3 systemd.show_status=false panic=5" -nographic
```

**虚拟机内测试指令：**
```bash
# 1. 读取我们写入的新用户影子证书内容
cat /etc/shadow
# 2. v0.8 已启用 console-login.service，开机直接出现登录提示
#    用户名：root
#    密码：123456（输入不回显）
# 3. 登录后验证 PAM 认证相关组件
systemctl status console-login.service
# 4. 使用 Switch User 工具验证 PAM 授权机制正常
su - root
# 5. 若当前已是 root，su 可能无提示直接返回，这是正常现象；用 shell 内建变量验证
echo "$USER"
```

---

## [v0.9] 网络架构组件

主要引进了 `ip` 等网络指令族和 OpenSSH 套件，测试通信能力。

**启动命令：**
```bash
qemu-system-x86_64 -kernel ./vmlinuz-6.8.0-90-generic -initrd initrd0.9.img -m 512 -cpu host -enable-kvm -append "root=/dev/ram0 rw console=ttyS0,115200 loglevel=3 systemd.show_status=false panic=5" -nographic
```

**虚拟机内测试指令：**
```bash
# 1. 查看本地所有支持的网络接口卡
ip addr
# 2. 检测本地回环堆栈的运转正常
ping -c 3 127.0.0.1
# 3. 尝试验证路由表组件 (当前应为空或只有 local 路由)
ip route
```

---

## [v1.0] 服务全功能态

最高版本测试系统开机时自动初始化运行了设定的网络配置和后台服务节点。

**启动命令：**
```bash
qemu-system-x86_64 -kernel ./vmlinuz-6.8.0-90-generic -initrd initrd1.0.img -m 512 -cpu host -enable-kvm -append "root=/dev/ram0 rw console=ttyS0,115200 loglevel=3 systemd.show_status=false panic=5" -nographic
```

> [!NOTE]
> 若宿主不支持 KVM，可去掉 `-enable-kvm -cpu host` 再测试。

**虚拟机内测试指令：**
```bash
# 1. 查看 network.service 是否按照预期为 eth0 接口挂载了 192.168.1.100 静态 ip
ip addr show eth0
# 2. 确认静态默认路由已经被 service 建立完毕
ip route
# 3. 查看从宿主机同步的 ssh 服务由于未找到二进制而处于失败降级状态的报错
systemctl status ssh.service
# 4. 分析整个系统的开机耗时组件分布
systemd-analyze
```
