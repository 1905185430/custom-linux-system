# Linux Initrd 构建项目

[![Version](https://img.shields.io/badge/version-v1.0-blue.svg)](docs/TEST_REPORT.md)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

从 v0.5 到 v1.0 逐步构建一个完整的自定义 Linux initrd 系统。

---

## 📁 项目结构

```
linux_class/
├── 📄 docs/              # 文档目录
│   ├── README.md         # 项目说明
│   ├── BUILD_GUIDE.md    # 完整构建指南
│   ├── TEST_REPORT.md    # 测试报告
│   ├── QEMU_DEBUG_GUIDE.md  # QEMU 调试指南
│   └── ...
│
├── 🔧 scripts/           # 脚本目录
│   ├── rebuild_all.sh    # 一键构建所有版本
│   ├── build.sh          # 单版本打包
│   ├── qemu-debug.sh     # QEMU 启动测试
│   ├── check-env.sh      # 环境检查
│   ├── test-all-versions.sh  # 自动化测试
│   └── Makefile          # Make 构建
│
├── 🧪 tests/             # 测试目录
├── 📊 results/           # 测试结果
│
├── 💿 initrd*.img        # 构建好的镜像
├── 📂 initrd*/           # 各版本源码
└── 🔨 其他配置文件
```

---

## 🚀 快速开始

### 1. 环境检查
```bash
./scripts/check-env.sh
```

### 2. 一键构建
```bash
cd scripts
make all
# 或
./rebuild_all.sh
```

### 3. 测试运行
```bash
# 交互式测试
./qemu-debug.sh v1.0 nographic

# 自动化测试
./test-all-versions.sh
```

---

## 📋 版本对照

| 版本 | 大小 | 核心功能 | 状态 |
|------|------|----------|------|
| **v0.5** | 4.2MB | 基础 initrd + bash | ✅ 通过 |
| **v0.6** | 45MB | + udev 硬件检测 | ✅ 通过 |
| **v0.7** | 48MB | + systemd 初始化 | ✅ 通过 |
| **v0.8** | 50MB | + 用户登录认证 | ✅ 通过 |
| **v0.9** | 52MB | + 网络 + SSH | ✅ 通过 |
| **v1.0** | 52MB | + 服务自启动 | ✅ 通过 |

---

## 📚 文档导航

| 文档 | 内容 |
|------|------|
| [BUILD_GUIDE.md](docs/BUILD_GUIDE.md) | 详细构建步骤和代码 |
| [TEST_REPORT.md](docs/TEST_REPORT.md) | 完整测试报告和分析 |
| [QEMU_DEBUG_GUIDE.md](docs/QEMU_DEBUG_GUIDE.md) | QEMU 调试技巧 |
| [testing_guide.md](docs/testing_guide.md) | 各版本测试命令 |

---

## 🛠️ 常用命令

```bash
# 构建
make all                    # 构建所有版本
make build                  # 同上
make clean                  # 清理构建

# 测试
make test                   # 测试所有版本
make run-v1.0               # 交互式运行 v1.0
./qemu-debug.sh v0.5        # 启动 v0.5

# 信息
make sizes                  # 显示镜像大小
make check                  # 检查环境
```

---

## 🎯 项目特点

- **渐进式构建**: 从 4MB 到 52MB，逐步添加功能
- **完整文档**: 每个版本都有详细说明
- **自动化测试**: 一键验证所有版本
- **实用脚本**: 构建、测试、调试全覆盖

---

## 📖 学习路径

1. 阅读 [BUILD_GUIDE.md](docs/BUILD_GUIDE.md) 了解构建过程
2. 查看 [TEST_REPORT.md](docs/TEST_REPORT.md) 了解测试结果
3. 运行 `./qemu-debug.sh v0.5 nographic` 体验最简系统
4. 逐步升级到 v1.0，观察功能变化

---

## 🤝 贡献

欢迎提交 Issue 和 PR！

---

## 📄 许可证

MIT License

---

*最后更新: 2025-04-13*
