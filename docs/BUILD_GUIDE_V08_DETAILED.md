# Linux Initrd v0.8 详细构建教程

## 从零开始构建用户登录认证系统

**文档版本**: 1.0  
**作者**: 璇璇子  
**日期**: 2025-04-13  
**目标读者**: Linux 初学者

---

## 📚 目录

1. [前言](#前言)
2. [基本概念](#基本概念)
3. [准备工作](#准备工作)
4. [详细构建步骤](#详细构建步骤)
5. [原理解析](#原理解析)
6. [测试验证](#测试验证)
7. [故障排查](#故障排查)
8. [扩展阅读](#扩展阅读)

---

## 前言

### 什么是 v0.8？

v0.8 是一个里程碑版本，它在前一版本（v0.7，systemd 初始化）的基础上，添加了**用户登录认证系统**。

### 为什么要学习 v0.8？

| 技能 | 说明 |
|------|------|
| 用户管理 | 理解 Linux 用户系统是如何工作的 |
| 认证机制 | 学习 PAM（Pluggable Authentication Modules） |
| 安全基础 | 了解密码存储、权限控制 |
| 系统启动 | 理解登录流程和 getty 服务 |

### 学完本教程你能做什么？

✅ 理解 Linux 登录流程  
✅ 手动构建带用户认证的最小系统  
✅ 掌握 PAM 配置方法  
✅ 理解 passwd/shadow 文件结构  

---

## 基本概念

### 1. Linux 用户系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Linux 用户系统                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │   /bin/login │───▶│    PAM      │───▶│  /etc/shadow │    │
│  │   (登录程序) │    │  (认证模块)  │    │  (密码存储)  │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│          │                   │                   │          │
│          ▼                   ▼                   ▼          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │  /etc/passwd │    │ lib/security│    │   crypt()   │    │
│  │  (用户信息)  │    │ (PAM 模块)  │    │  (加密算法)  │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2. 关键文件说明

#### /etc/passwd - 用户账户信息

```
root:x:0:0:root:/root:/bin/bash
 │  │ │ │  │    │      │
 │  │ │ │  │    │      └─ 默认 Shell
 │  │ │ │  │    └─ 家目录
 │  │ │ │  └─ 用户全称
 │  │ │ └─ GID (组ID)
 │  │ └─ UID (用户ID)  
 │  └─ 密码占位符 (x 表示密码在 shadow 中)
 └─ 用户名
```

#### /etc/shadow - 密码哈希

```
root:$6$7YAxwv...:19812:0:99999:7:::
 │    │            │     │ │    │
 │    │            │     │ │    └─ 保留字段
 │    │            │     │ └─ 警告天数
 │    │            │     └─ 最大密码年龄
 │    │            └─ 最小密码年龄
 │    └─ 加密的密码 (算法+盐+哈希)
 └─ 用户名
```

**密码格式**: `$id$salt$encrypted`
- `$6$` = SHA-512 算法
- `$1$` = MD5 (旧)
- `$5$` = SHA-256

#### /etc/pam.d/login - PAM 配置

```
auth     required   pam_unix.so nullok
 │        │          │
 │        │          └─ PAM 模块及参数
 │        └─ 控制标志 (required/sufficient/optional)
 └─ 管理类型 (auth/account/session/password)
```

**控制标志**:
- `required` - 必须成功，失败会继续但最终失败
- `sufficient` - 成功则立即返回成功，失败忽略
- `optional` - 成功与否都不影响结果

### 3. PAM (Pluggable Authentication Modules)

#### 什么是 PAM？

PAM 是 Linux 的认证框架，将认证逻辑从应用程序中分离出来。

#### 为什么需要 PAM？

**没有 PAM 时**:
```
login 程序 ──硬编码──▶ 检查 /etc/passwd 密码
                │
                └── 想改认证方式？重新编译 login！
```

**有 PAM 时**:
```
login 程序 ──PAM API──▶ PAM 框架 ──配置文件──▶ 认证模块
                              │
                              └── 想改认证？改配置文件！
```

#### PAM 的优势

| 特性 | 说明 |
|------|------|
| 模块化 | 认证逻辑在单独的 .so 文件中 |
| 可配置 | 通过配置文件灵活调整 |
| 可扩展 | 支持 LDAP、Kerberos、指纹等 |

---

## 准备工作

### 系统要求

- **操作系统**: Ubuntu 22.04 LTS
- **内核**: 6.8.0-90-generic
- **架构**: x86_64
- **权限**: root 或 sudo

### 前置知识

- 已了解 v0.5-v0.7 的构建（推荐先学习 v0.7）
- 基本的 Linux 命令
- 了解 systemd 基础

### 需要的工具

```bash
# 确认工具已安装
which ldd      # 查看程序依赖
which cpio     # 打包工具
which gzip     # 压缩工具
which qemu-system-x86_64  # 测试工具
```

### 准备工作目录

```bash
# 进入项目目录
cd ~/linux_class

# 确认 v0.7 存在
ls -la initrd0.7/
```

---

## 详细构建步骤

### 步骤 1: 清理并准备环境

**目标**: 创建干净的工作目录

```bash
# 清理旧版本（如果有）
rm -rf initrd0.8 initrd0.8.img

# 从 v0.7 复制基础系统
cp -a initrd0.7 initrd0.8

# 进入工作目录
cd initrd0.8
```

**原理说明**:
- `cp -a` 保留所有属性（权限、时间戳、软链接）
- v0.7 已包含 systemd，我们在此基础上添加登录功能

**验证**:
```bash
ls -la
# 应看到: bin, dev, etc, init, lib, lib64, proc, root, sbin, sys, tmp
```

---

### 步骤 2: 复制用户认证文件

#### 2.1 复制 /etc/passwd

**命令**:
```bash
cp /etc/passwd etc/
```

**原理**:
- passwd 文件存储用户账户信息
- 包含用户名、UID、GID、家目录、Shell
- 密码字段显示为 `x`，实际密码在 shadow 中

**查看内容**:
```bash
cat etc/passwd | head -5
```

**输出示例**:
```
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
```

#### 2.2 创建 /etc/shadow

**命令**:
```bash
# 创建 shadow 文件，密码为 "123456"
cat > etc/shadow << 'EOF'
root:$6$7YAxwvXa321ekF0A$FHdC1C62d96UXoRF5hYxFcx8IhPqq/QFtQhD0/hBT.Glvif/7Pq1HTiFTx/Ydoo3VG7CVkbhW8M0f9.ECM0IB1:19812:0:99999:7:::
EOF

# 设置权限（只有 root 可读）
chmod 400 etc/shadow
```

**原理解析**:

**为什么需要 shadow？**

早期密码直接存储在 passwd 中：
```
root:abcdef:0:0...  # 任何人都能看到密码！
```

现代系统分离存储：
```
passwd:  root:x:0:0...      # 公开信息
shadow:  root:$6$...:...   # 敏感信息（root 只读）
```

**密码哈希生成原理**:

```
密码: "123456"
   ↓
加入盐 (salt): "7YAxwvXa321ekF0A"
   ↓
SHA-512 哈希: "FHdC1C62d96UXoRF..."
   ↓
存储: $6$7YAxwvXa321ekF0A$FHdC1C62d...
```

**为什么是 $6$？**
- `$1$` = MD5
- `$5$` = SHA-256  
- `$6$` = SHA-512（推荐，最安全）

**验证**:
```bash
ls -la etc/shadow
# 应显示: -r-------- 1 root root ... /etc/shadow
```

#### 2.3 复制 /etc/group

**命令**:
```bash
cp /etc/group etc/
```

**原理**:
- 存储用户组信息
- 包含组名、GID、成员列表

**查看**:
```bash
cat etc/group | head -5
```

#### 2.4 复制 nsswitch.conf

**命令**:
```bash
cp /etc/nsswitch.conf etc/ 2>/dev/null || true
```

**原理**:
- Name Service Switch 配置文件
- 告诉系统如何查找用户信息
- 例如：优先从 files (/etc/passwd) 还是 ldap 查询

**关键配置行**:
```
passwd:     files        # 从 /etc/passwd 查找用户
shadow:     files        # 从 /etc/shadow 查找密码
group:      files        # 从 /etc/group 查找组
```

---

### 步骤 3: 复制登录程序

#### 3.1 复制 /bin/login

**命令**:
```bash
cp /bin/login bin/
```

**程序功能**:
- 显示登录提示（"login:"）
- 读取用户名和密码
- 调用 PAM 进行认证
- 成功后启动用户 Shell

**工作流程**:
```
1. 显示 "login:"
2. 读取用户名
3. 显示 "Password:"（不回显）
4. 读取密码
5. 调用 PAM 验证
6. 验证成功 ──▶ 启动 Shell
7. 验证失败 ──▶ 显示 "Login incorrect"
```

#### 3.2 复制 /bin/su

**命令**:
```bash
cp /bin/su bin/ 2>/dev/null || true
```

**功能**:
- Switch User，切换用户
- `su - root` 切换到 root 并加载其环境
- 同样使用 PAM 认证

#### 3.3 复制 /usr/bin/passwd

**命令**:
```bash
cp /usr/bin/passwd usr/bin/ 2>/dev/null || true
```

**功能**:
- 修改密码
- 会更新 /etc/shadow

---

### 步骤 4: 复制依赖库

#### 4.1 复制 login 的依赖

**命令**:
```bash
# 查看 login 依赖哪些库
ldd /bin/login

# 自动复制所有依赖到 lib/
ldd /bin/login | grep -o '/lib[^[:space:]]*' | while read lib; do
    if [ -f "$lib" ]; then
        cp -n "$lib" lib/
    fi
done
```

**关键依赖库**:

| 库文件 | 功能 |
|--------|------|
| libpam.so.0 | PAM 核心库 |
| libpam_misc.so.0 | PAM 辅助函数 |
| libaudit.so.1 | 审计日志 |
| libc.so.6 | C 标准库 |

#### 4.2 复制 PAM 模块

**命令**:
```bash
# 创建 PAM 模块目录
mkdir -p lib/security

# 复制核心 PAM 模块
cp /lib/x86_64-linux-gnu/security/pam_unix.so lib/security/
cp /lib/x86_64-linux-gnu/security/pam_permit.so lib/security/
cp /lib/x86_64-linux-gnu/security/pam_deny.so lib/security/
```

**PAM 模块说明**:

| 模块 | 功能 |
|------|------|
| pam_unix.so | Unix 传统认证（passwd/shadow） |
| pam_permit.so | 总是允许（测试用） |
| pam_deny.so | 总是拒绝 |

#### 4.3 复制 NSS 库

**命令**:
```bash
cp /lib/x86_64-linux-gnu/libnss_files.so.2 lib/
cp /lib/x86_64-linux-gnu/libnss_compat.so.2 lib/ 2>/dev/null || true
```

**原理**:
- NSS (Name Service Switch) 库
- 提供 `getpwnam()` 等函数，用于查询用户信息
- 让系统知道从 /etc/passwd 读取用户信息

**工作流程**:
```
login 调用 getpwnam("root")
    ↓
NSS 根据 nsswitch.conf 决定从哪查询
    ↓
libnss_files.so 从 /etc/passwd 读取
    ↓
返回用户信息
```

#### 4.4 复制 PAM 模块的依赖

**命令**:
```bash
# pam_unix.so 需要这些库
for lib in libcrypt.so.1 libselinux.so.1 libnsl.so.2 libtirpc.so.3 \
           libpcre2-8.so.0 libcap-ng.so.0 libresolv.so.2; do
    if [ -f "/lib/x86_64-linux-gnu/$lib" ]; then
        cp "/lib/x86_64-linux-gnu/$lib" lib/
    fi
done
```

---

### 步骤 5: 创建 PAM 配置文件

#### 5.1 创建 /etc/pam.d/login

**命令**:
```bash
cat > etc/pam.d/login << 'EOF'
# PAM configuration for login
auth       required   pam_unix.so nullok
account    required   pam_unix.so
session    required   pam_unix.so
EOF
```

**配置解释**:
```
auth     required   pam_unix.so nullok
│        │          │           │
│        │          │           └── 允许空密码
│        │          └─ 使用 Unix 传统认证
│        └─ 必须成功
└─ 认证阶段（验证密码）

account  required   pam_unix.so
│        │          │
│        │          └─ 检查账户状态
│        └─ 必须成功
└─ 账户阶段（检查是否过期等）

session  required   pam_unix.so
│        │          │
│        │          └─ 设置会话
│        └─ 必须成功
└─ 会话阶段（记录日志等）
```

#### 5.2 创建 common-* 文件

**命令**:
```bash
# common-auth
echo 'auth    required    pam_unix.so nullok' > etc/pam.d/common-auth

# common-account
echo 'account required    pam_unix.so' > etc/pam.d/common-account

# common-session
echo 'session required    pam_unix.so' > etc/pam.d/common-session
```

#### 5.3 创建 /etc/pam.d/su

**命令**:
```bash
cat > etc/pam.d/su << 'EOF'
# PAM configuration for su
auth    sufficient    pam_permit.so
account sufficient    pam_permit.so
session sufficient    pam_permit.so
EOF
```

**说明**:
- 使用 `pam_permit.so` 简化 su 认证
- 生产环境应使用更严格的配置

---

### 步骤 6: 创建 systemd 服务

#### 6.1 创建 console-login.service

**命令**:
```bash
mkdir -p etc/systemd/system/multi-user.target.wants

cat > etc/systemd/system/console-login.service << 'EOF'
[Unit]
Description=Console Login Prompt
After=multi-user.target

[Service]
Type=idle
TTYPath=/dev/ttyS0
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
ExecStart=/bin/login
StandardInput=tty-force
StandardOutput=tty
StandardError=tty
Restart=always
RestartSec=0

[Install]
WantedBy=multi-user.target
EOF
```

**配置解释**:

| 参数 | 说明 |
|------|------|
| Type=idle | 等待其他服务启动完成后再启动 |
| TTYPath=/dev/ttyS0 | 使用串口控制台 |
| TTYReset=yes | 启动前重置 TTY |
| ExecStart=/bin/login | 启动 login 程序 |
| Restart=always | 总是重启（用户退出后重新登录） |

#### 6.2 启用服务

**命令**:
```bash
# 启用 console-login 服务
ln -sf /etc/systemd/system/console-login.service \
    etc/systemd/system/multi-user.target.wants/

# 移除 v0.7 的 bash 服务
rm -f etc/systemd/system/multi-user.target.wants/bash.service
rm -f etc/systemd/system/bash.service
```

**原理**:
- systemd 启动时会自动启动 `multi-user.target.wants/` 中的服务
- 我们移除 bash 服务，替换为 console-login 服务
- 这样系统启动后会出现登录提示而不是直接进入 shell

---

### 步骤 7: 更新 init 脚本

**命令**:
```bash
cat > init << 'EOF'
#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

echo "[v0.8] Mounting virtual filesystems..."
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# 创建必要的运行时目录
mkdir -p /run /run/udev /var/run

echo "[v0.8] Starting udev daemon..."
/lib/systemd/systemd-udevd --daemon
/bin/udevadm trigger --action=add
/bin/udevadm settle
echo "[v0.8] Hardware drivers loaded!"

echo "[v0.8] Starting systemd..."
ln -sf /lib/systemd/systemd /sbin/init 2>/dev/null || true
exec /lib/systemd/systemd
EOF

chmod +x init
```

**修改说明**:
- 添加 `/run` 目录创建（systemd 和 PAM 需要）
- 添加 `/var/run` 目录（兼容性）
- 修改版本号为 [v0.8]

---

### 步骤 8: 复制 login.defs

**命令**:
```bash
cp /etc/login.defs etc/

# 可选：禁用登录超时
sed -i 's/^LOGIN_TIMEOUT.*/LOGIN_TIMEOUT 0/' etc/login.defs
```

**作用**:
- login.defs 包含登录程序的默认配置
- 如登录超时时间、密码策略等

---

### 步骤 9: 打包镜像

**命令**:
```bash
cd ~/linux_class/initrd0.8

# 打包（-1 表示快速压缩）
find . -print0 | cpio --null -ov --format=newc | gzip -1 > ../initrd0.8.img

# 查看结果
ls -lh ../initrd0.8.img
```

**打包原理**:
- `find .` 列出所有文件
- `cpio` 将文件打包（--format=newc 表示新格式）
- `gzip` 压缩（-1 表示最快压缩，适合测试）

**预期大小**: 约 50-60MB

---

### 步骤 10: 验证镜像

**检查 gzip 完整性**:
```bash
cd ~/linux_class
gzip -t initrd0.8.img && echo "✓ 镜像完整"
```

**检查关键文件**:
```bash
# 解压检查
mkdir -p /tmp/check_v08
cd /tmp/check_v08
gzip -dc ~/linux_class/initrd0.8.img | cpio -id

# 验证关键文件
ls -la init bin/login etc/shadow etc/passwd etc/pam.d/login

# 清理
cd ~
rm -rf /tmp/check_v08
```

---

## 测试验证

### 启动命令

```bash
cd ~/linux_class
qemu-system-x86_64 \
    -kernel ./vmlinuz-6.8.0-90-generic \
    -initrd initrd0.8.img \
    -m 1024 \
    -append "root=/dev/ram0 rw console=ttyS0,115200" \
    -nographic
```

### 登录测试

**步骤**:
1. 等待出现 `localhost login:`
2. 输入用户名: `root`
3. 输入密码: `123456`（不回显）
4. 看到 `-bash-5.1#` 表示登录成功

### 功能测试命令

```bash
# 1. 检查当前用户
id                    # 应显示 uid=0(root)

# 2. 检查用户名
whoami                # 应显示 root

# 3. 检查家目录
pwd                   # 应显示 /root

# 4. 检查用户文件
cat /etc/passwd       # 应包含 root 用户

# 5. 检查 shadow 文件
ls -la /etc/shadow    # 权限应为 -r--------

# 6. 检查 PAM 配置
ls /etc/pam.d/        # 应包含 login, su 等

# 7. 检查登录服务
systemctl status console-login.service

# 8. 检查 PAM 库
ls /lib/security/     # 应包含 pam_unix.so

# 9. 测试 su 命令
su - root             # 应切换到 root

# 10. 检查环境变量
echo $USER            # 应显示 root
```

---

## 故障排查

### 问题 1: 登录提示不出现

**现象**: 系统启动后没有 `login:` 提示

**排查**:
```bash
# 检查 console-login 服务是否运行
systemctl status console-login.service

# 检查 /bin/login 是否存在
ls -la /bin/login

# 手动启动 login
/bin/login
```

### 问题 2: 密码总是错误

**现象**: 输入正确密码仍显示 "Login incorrect"

**排查**:
```bash
# 检查 shadow 文件格式
cat /etc/shadow | head -1
# 应显示: root:$6$... (不是 root:\$6\$...)

# 检查 PAM 配置
cat /etc/pam.d/login

# 检查 PAM 库是否存在
ls /lib/security/pam_unix.so
```

### 问题 3: su 命令失败

**现象**: `su - root` 报错

**排查**:
```bash
# 检查 su 的 PAM 配置
cat /etc/pam.d/su

# 使用 pam_permit.so 简化配置
echo 'auth sufficient pam_permit.so' > /etc/pam.d/su
```

---

## 扩展阅读

### 相关命令

| 命令 | 作用 |
|------|------|
| `useradd` | 添加用户 |
| `passwd` | 修改密码 |
| `su` | 切换用户 |
| `sudo` | 以其他用户执行命令 |
| `groups` | 查看用户所属组 |
| `chown` | 修改文件所有者 |
| `chmod` | 修改文件权限 |

### 相关文件

| 文件 | 作用 |
|------|------|
| /etc/passwd | 用户账户信息 |
| /etc/shadow | 密码哈希 |
| /etc/group | 组信息 |
| /etc/gshadow | 组密码 |
| /etc/pam.d/* | PAM 配置 |
| /etc/nsswitch.conf | NSS 配置 |
| /etc/login.defs | 登录配置 |

### 深入学习

1. **PAM 文档**: `man pam`
2. **login 文档**: `man login`
3. **shadow 格式**: `man 5 shadow`
4. **NSS 配置**: `man 5 nsswitch.conf`

---

## 总结

### 构建流程图

```
┌─────────────┐
│  从 v0.7    │
│  复制基础   │
└──────┬──────┘
       ▼
┌─────────────┐
│ 复制用户    │
│ 认证文件    │
│ (passwd,    │
│  shadow)    │
└──────┬──────┘
       ▼
┌─────────────┐
│ 复制登录    │
│ 程序        │
│ (login, su) │
└──────┬──────┘
       ▼
┌─────────────┐
│ 复制 PAM    │
│ 库和配置    │
└──────┬──────┘
       ▼
┌─────────────┐
│ 创建 systemd│
│ 服务        │
└──────┬──────┘
       ▼
┌─────────────┐
│ 打包镜像    │
└─────────────┘
```

### 关键要点

1. **shadow 文件权限**必须是 400（root 只读）
2. **PAM 库**必须完整，特别是 libpam_misc.so.0
3. **NSS 库**（libnss_files.so.2）用于查询用户信息
4. **systemd 服务**配置决定启动流程
5. **运行时目录**（/run）必须提前创建

---

**文档结束**

如需帮助，请参考项目中的其他文档：
- BUILD_GUIDE.md - 整体构建指南
- TEST_REPORT.md - 测试报告
- QEMU_DEBUG_GUIDE.md - QEMU 调试技巧
