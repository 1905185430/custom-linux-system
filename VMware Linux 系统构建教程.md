这是一份基于您提供的报告文档整理的“极简 Linux 系统构建与内核裁剪”实战教程。教程分为六个核心任务检查点，专为在 VMware 环境下操作而设计。

## **任务一：环境准备与基础认知**

* 准备宿主机环境，在 VMware 中安装 Ubuntu 22.10 虚拟机（配置建议：8核，4G内存，40G硬盘）。

* 理解 Linux 启动项的核心构成：内核 (Kernel) \+ 初始内存盘 (initrd) \+ 配置文件 (Config) \+ 驱动模块 (modules) \+ grub.config 。

* 熟悉 initrd 的核心作用，包括设置环境变量、创建必要目录、加载驱动程序以及最终挂载并切换到真实的根文件系统 。

## **任务二：构建基础 initrd (v0.5 \- v0.55)**

* 在用户主目录下创建一个工作目录（如 initrd0.5），并构建基本的文件系统结构，包括 /bin、/dev、/etc、/proc、/sys、/tmp、/root 和 /sbin 目录 。

* 将基础的 shell 程序（/bin/sh 和 /bin/bash）复制到新系统的 /bin 目录下 。

* 使用 ldd 命令查找 bash 依赖的动态链接库，并将其原封不动地移动到新系统的对应目录中，随后使用 chroot 命令进行验证 。

* 编写初始的 init 脚本（存放于根目录），内容需包含挂载 proc 和 sysfs，以及执行 /bin/bash 。

* 使用 cp 命令移入更多基础指令，如 ls、mkdir、cat、mount 等，并同样使用 ldd 迁移依赖库 。

* 手动将所需的硬件驱动（如 /lib/modules/.../kernel/drivers/ 下的 message、scsi、ata 内容）转移到小系统中 。

* 打包该镜像文件，复制到 /boot/ 目录下，并在 /etc/grub.d/40\_custom 中添加自定义启动项配置 。

* 修改 /etc/default/grub 文件以显示 GRUB 菜单，执行 sudo update-grub 后重启虚拟机进行初步验证 。

## **任务三：集成高级系统服务 (v0.6 \- v0.9)**

* 迁移 Udev 依赖：将 /lib/systemd/systemd-udevd、/bin/udevadm 及相关规则迁移至小系统，修改 init 脚本以自动加载硬件驱动和触发设备添加动作 。

* 迁移 Systemd 依赖：将 /bin/systemd、/bin/systemctl 及 /lib/systemd/system/ 下的基础目标（如 multi-user.target）迁移进来 。

* 创建自定义的 bash.service 文件于 etc/systemd/system/ 目录下，并配置为在 multi-user.target 之后启动交互式 Bash 。

* 更新 init 脚本，将最终的执行命令替换为 exec /lib/systemd/systemd，由 systemd 接管后续启动流程 。

* 迁移用户登录凭证与安全模块：复制 /etc/passwd、/etc/shadow、/bin/login 以及 /etc/pam.d 和 /etc/nsswitch.conf 等身份验证配置文件 。

* 注意文件权限安全：避免误操作损坏宿主机的 shadow 文件，若损坏可通过已构建好的高权限小系统使用 cat 命令将备份写回 。

## **任务四：内核获取与深度裁剪**

* 从 Linux 官方网站下载 linux-6.12.25 版本的内核源码并解压 。

* 在源码目录执行 make localmodconfig 生成匹配本地基础环境的 .config 文件 。

* 执行 make menuconfig 开启图形化配置界面，开始进行内核精简 。

* 禁用不需要的庞大模块：如 Kernel Hacking、Security options、推测执行漏洞缓解（Mitigations for speculative execution vulnerabilities）以及无关的设备驱动（如声卡、无用的文件系统等） 。

* 针对 VMware 虚拟机的特定报错（No EFI Environment detected），在配置中禁用 CONFIG\_EFI 和 CONFIG\_FB\_EFI 以取消 EFI 模式启动依赖 。

* 修改内核发布名称（如设为 .2 或 .3）以区分不同版本，并在 General Setup 中将内核压缩方式更改为 LZMA 以进一步减小体积 。

* 执行 make \-j 8 编译内核，然后使用 make modules\_install 和 make install 完成安装 。

## **任务五：网络配置与 SSH 服务搭建**

* 将网络相关命令（ifconfig、ping、ssh、sshd、ip、route）及其依赖迁入小系统 。

* 迁入目标网卡驱动，例如 Intel e1000 网卡驱动模块（e1000.ko.zst 或 e1000e） 。

* 在宿主机使用 ip addr 和 route \-n 获取当前的 IP 段和网关信息，并在小系统编写 network.service 进行静态 IP 挂载 。

* 在 network.service 中，使用 ip addr replace 代替 add 指令，以防止服务重启时因地址已存在而报错 。

* 迁入 SSH 核心配置：复制 /etc/ssh/ 目录下的所有内容、密钥文件以及全局环境变量配置 /etc/profile 。

* 修复 SSH 密钥权限错误：确保 SSH 的私钥文件（如 ssh\_host\_rsa\_key）权限不能过高（不能是 0777），否则会被服务忽略导致启动失败 。

* 修改小系统的 /etc/ssh/sshd\_config 文件，添加 PermitRootLogin yes 以允许 Windows 宿主机通过 root 身份直接远程连接 。

## **任务六：U盘挂载与独立启动盘制作**

* 确保 VMware 虚拟机设置中开启了对 USB 3.1 协议的支持，以保证 U 盘能被底层系统正确识别 。

* 将 U 盘连接至虚拟机，在小系统中使用 mount /dev/sdb1 /mnt 命令进行手动挂载验证，测试读写与热插拔功能 。

* 在大系统中开始制作启动盘：取消 U 盘挂载后，使用 parted 工具创建 MBR 分区表，并分出一个格式为 FAT32 的主分区，标记为启动分区 (boot on) 。

* 使用 mkfs.fat \-F32 对该分区进行格式化 。

* 挂载该 U 盘分区，执行 grub-install \--target=i386-pc \--recheck \--boot-directory=/mnt/usb/boot /dev/sdb 命令将 GRUB 引导程序安装入 U 盘 。

* 将之前裁剪好的内核文件 (bzImage) 和自定义文件系统 (initrd.img) 复制到 U 盘的 boot 路径下 。

* 在 U 盘的 GRUB 目录中手动编写 grub.cfg 文件，指定 root='(hd0,msdos1)' 并正确指向 linux 内核与 initrd 文件的路径，完成系统脱机启动盘的制作 。  
