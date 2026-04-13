# Linux Initrd 构建项目

[![Version](https://img.shields.io/badge/version-v1.0-blue.svg)](docs/TEST_REPORT.md)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

从 v0.5 到 v1.0 逐步构建一个完整的自定义 Linux initrd 系统。

---

## 📚 项目概述

本项目通过 6 个版本（v0.5 → v1.0）的渐进式构建，从零开始创建一个功能完整的 Linux 系统：

| 版本 | 大小 | 核心功能 | 详细教程 |
|------|------|----------|----------|
| **v0.5** | 4.2MB | 最小 Linux 系统（bash + 基本命令） | [📖 详细教程](docs/BUILD_GUIDE_V05_DETAILED.md) |
| **v0.6** | 45MB | + udev 硬件检测 | [📖 详细教程](docs/BUILD_GUIDE_V06_DETAILED.md) |
| **v0.7** | 48MB | + systemd 系统初始化 | [📖 详细教程](docs/BUILD_GUIDE_V07_DETAILED.md) |
| **v0.8** | 54MB | + 用户登录认证（PAM） | [📖 详细教程](docs/BUILD_GUIDE_V08_DETAILED.md) |
| **v0.9** | 52MB | + 网络 + SSH | [📖 详细教程](docs/testing_guide.md) |
| **v1.0** | 52MB | + 服务自启动 | [📖 详细教程](docs/testing_guide.md) |

**所有版本测试通过！** ✅ 查看 [测试报告](docs/TEST_REPORT.md)

---

## 🚀 快速开始

### 环境要求

- **OS**: Ubuntu 22.04 LTS
- **Kernel**: 6.8.0-90-generic
- **Arch**: x86_64
- **Tools**: QEMU, cpio, gzip

### 1. 克隆项目

```bash
git clone https://github.com/1905185430/custom-linux-system.git
cd custom-linux-system
```

### 2. 环境检查

```bash
./scripts/check-env.sh
```

### 3. 一键构建所有版本

```bash
cd scripts
make all
# 或
./rebuild_all.sh
```

### 4. 测试运行

```bash
# 启动 v0.5（最小系统）
./qemu-debug.sh v0.5 nographic

# 启动 v0.8（用户认证）
./qemu-debug.sh v0.8 nographic

# 启动 v1.0（完整系统）
./qemu-debug.sh v1.0 nographic
```

---

## 📁 项目结构

```
linux_class/
├── 📄 docs/                          # 文档目录
│   ├── BUILD_GUIDE_V05_DETAILED.md   # v0.5 详细构建教程
│   ├── BUILD_GUIDE_V06_DETAILED.md   # v0.6 详细构建教程
│   ├── BUILD_GUIDE_V07_DETAILED.md   # v0.7 详细构建教程
│   ├── BUILD_GUIDE_V08_DETAILED.md   # v0.8 详细构建教程
│   ├── BUILD_GUIDE.md                # 整体构建指南
│   ├── TEST_REPORT.md                # 测试报告
│   ├── DETAILED_VERIFICATION_REPORT.md  # 验证报告
│   ├── QEMU_DEBUG_GUIDE.md           # QEMU 调试指南
│   └── ...
│
├── 🔧 scripts/                       # 脚本目录
│   ├── rebuild_all.sh                # 一键构建所有版本
│   ├── build.sh                      # 单版本打包
│   ├── qemu-debug.sh                 # QEMU 启动测试
│   ├── build-v08-workflow.sh         # v0.8 构建工作流
│   ├── auto_test_v08.py              # v0.8 自动化测试
│   ├── test-all-versions.sh          # 全版本测试
│   ├── check-env.sh                  # 环境检查
│   └── Makefile                      # Make 构建
│
├── 🧪 tests/                         # 测试目录
├── 📊 results/                       # 测试结果
│
├── 💿 initrd*.img                    # 构建好的镜像（7个）
├── 📂 initrd*/                       # 各版本源码目录
├── 🔨 vmlinuz-*                      # 内核文件
├── 📋 README.md                      # 本文件
└── 📋 PROJECT_SUMMARY.md             # 项目总结
```

---

## 📖 学习路径

### 新手推荐

1. **先读 v0.5 教程** → 理解最小 Linux 系统
   ```bash
   cat docs/BUILD_GUIDE_V05_DETAILED.md
   ```

2. **动手构建 v0.5** → 体验从零开始
   ```bash
   cd scripts && ./qemu-debug.sh v0.5 nographic
   ```

3. **逐步学习 v0.6-v0.8** → 理解每个组件
   - v0.6: udev 硬件检测
   - v0.7: systemd 初始化
   - v0.8: 用户登录认证

4. **查看测试报告** → 验证理解
   ```bash
   cat docs/TEST_REPORT.md
   ```

### 快速体验

```bash
# 测试所有版本（自动化）
./scripts/test-all-versions.sh

# 查看镜像大小
make -C scripts sizes
```

---

## 🛠️ 常用命令

### 构建命令

```bash
cd scripts

make all                    # 构建所有版本
make build                  # 同上
make clean                  # 清理构建产物
make sizes                  # 显示各版本镜像大小
```

### 测试命令

```bash
./qemu-debug.sh v0.5        # 启动 v0.5
./qemu-debug.sh v0.6        # 启动 v0.6
./qemu-debug.sh v0.7        # 启动 v0.7
./qemu-debug.sh v0.8        # 启动 v0.8
./qemu-debug.sh v1.0        # 启动 v1.0

./test-all-versions.sh      # 自动化测试所有版本
```

### 信息命令

```bash
make check                  # 检查构建环境
file initrd*.img            # 检查镜像格式
ls -lh initrd*.img          # 查看镜像大小
```

---

## 🎯 项目特点

- ✅ **渐进式学习**: 6 个版本，从 4MB 到 52MB，功能逐步增加
- ✅ **详细文档**: 每个版本都有详细的构建教程和原理解析
- ✅ **完整测试**: 自动化测试脚本，一键验证所有版本
- ✅ **实用工具**: 构建、测试、调试全覆盖的脚本工具
- ✅ **真实可用**: 所有版本都经过测试，可以实际运行

---

## 📚 文档索引

### 构建教程

| 文档 | 说明 | 适合 |
|------|------|------|
| [BUILD_GUIDE_V05_DETAILED.md](docs/BUILD_GUIDE_V05_DETAILED.md) | v0.5 最小系统 | 初学者 |
| [BUILD_GUIDE_V06_DETAILED.md](docs/BUILD_GUIDE_V06_DETAILED.md) | v0.6 udev | 初学者 |
| [BUILD_GUIDE_V07_DETAILED.md](docs/BUILD_GUIDE_V07_DETAILED.md) | v0.7 systemd | 初学者 |
| [BUILD_GUIDE_V08_DETAILED.md](docs/BUILD_GUIDE_V08_DETAILED.md) | v0.8 用户认证 | 初学者 |
| [BUILD_GUIDE.md](docs/BUILD_GUIDE.md) | 整体构建指南 | 进阶 |

### 测试与调试

| 文档 | 说明 |
|------|------|
| [TEST_REPORT.md](docs/TEST_REPORT.md) | 完整测试报告 |
| [DETAILED_VERIFICATION_REPORT.md](docs/DETAILED_VERIFICATION_REPORT.md) | 详细验证报告 |
| [QEMU_DEBUG_GUIDE.md](docs/QEMU_DEBUG_GUIDE.md) | QEMU 调试技巧 |
| [testing_guide.md](docs/testing_guide.md) | 各版本测试命令 |

### 其他

| 文档 | 说明 |
|------|------|
| [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) | 项目完整总结 |
| [QUICK_START.md](docs/QUICK_START.md) | 快速开始指南 |
| [GITHUB_PUSH_GUIDE.md](docs/GITHUB_PUSH_GUIDE.md) | GitHub 推送指南 |

---

## 🔬 技术栈

- **Linux Kernel**: 6.8.0-90-generic
- **Init System**: systemd 249
- **Shell**: bash 5.1
- **Build Tools**: cpio, gzip, make
- **Testing**: QEMU 6.2.0
- **Version Control**: Git

---

## 🤝 贡献

欢迎提交 Issue 和 PR！

- 发现问题？提交 Issue
- 改进文档？提交 PR
- 新功能建议？欢迎讨论

---

## 📄 许可证

MIT License

---

## 🙏 致谢

- [Linux From Scratch](https://www.linuxfromscratch.org/) - Linux 构建参考
- [systemd](https://systemd.io/) - 系统初始化
- [QEMU](https://www.qemu.org/) - 虚拟化测试

---

*最后更新: 2025-04-13*  
*作者: 璇璇子*  
*项目地址: https://github.com/1905185430/custom-linux-system*
