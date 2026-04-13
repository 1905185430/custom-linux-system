# Linux Initrd 构建项目 Makefile
# 一键构建、测试、清理

.PHONY: all build test clean check help

# 默认目标
all: build

# 显示帮助
help:
	@echo "Linux Initrd 构建项目"
	@echo ""
	@echo "可用目标:"
	@echo "  make build      - 构建所有版本的 initrd 镜像"
	@echo "  make test       - 运行所有版本的自动化测试"
	@echo "  make test-v0.5  - 仅测试 v0.5 版本"
	@echo "  make test-v0.6  - 仅测试 v0.6 版本"
	@echo "  make test-v0.7  - 仅测试 v0.7 版本"
	@echo "  make test-v0.8  - 仅测试 v0.8 版本"
	@echo "  make test-v0.9  - 仅测试 v0.9 版本"
	@echo "  make test-v1.0  - 仅测试 v1.0 版本"
	@echo "  make check      - 检查构建环境"
	@echo "  make clean      - 清理构建产物"
	@echo "  make optimize   - 优化镜像大小"
	@echo "  make sizes      - 显示各版本镜像大小"

# 检查环境
check:
	@echo "🔍 检查构建环境..."
	@./check-env.sh

# 构建所有版本
build:
	@echo "🔨 开始构建所有版本..."
	@./rebuild_all.sh 2>&1 | tee build.log
	@echo "✅ 构建完成！日志保存到 build.log"

# 测试所有版本
test: test-v0.5 test-v0.6 test-v0.7 test-v0.8 test-v0.9 test-v1.0
	@echo ""
	@echo "✅ 所有版本测试完成！"
	@cat test_results/summary.txt 2>/dev/null || echo "测试结果保存在 test_results/"

# 测试单个版本
test-v0.5:
	@echo "🧪 测试 v0.5..."
	@mkdir -p test_results
	@./test-version.sh v0.5 2>&1 | tee test_results/v0.5.log

test-v0.6:
	@echo "🧪 测试 v0.6..."
	@mkdir -p test_results
	@./test-version.sh v0.6 2>&1 | tee test_results/v0.6.log

test-v0.7:
	@echo "🧪 测试 v0.7..."
	@mkdir -p test_results
	@./test-version.sh v0.7 2>&1 | tee test_results/v0.7.log

test-v0.8:
	@echo "🧪 测试 v0.8..."
	@mkdir -p test_results
	@./test-version.sh v0.8 2>&1 | tee test_results/v0.8.log

test-v0.9:
	@echo "🧪 测试 v0.9..."
	@mkdir -p test_results
	@./test-version.sh v0.9 2>&1 | tee test_results/v0.9.log

test-v1.0:
	@echo "🧪 测试 v1.0..."
	@mkdir -p test_results
	@./test-version.sh v1.0 2>&1 | tee test_results/v1.0.log

# 清理构建产物
clean:
	@echo "🧹 清理构建产物..."
	@rm -rf initrd0.5 initrd0.6 initrd0.7 initrd0.8 initrd0.9 initrd1.0
	@rm -f build.log
	@rm -rf test_results
	@echo "✅ 清理完成！镜像文件保留"

# 显示镜像大小
sizes:
	@echo "📦 各版本镜像大小:"
	@ls -lh initrd*.img 2>/dev/null | awk '{printf "  %-15s %s\n", $$9, $$5}'

# 优化镜像
optimize:
	@echo "⚡ 优化镜像大小..."
	@./optimize.sh 2>&1 | tee optimize.log

# 交互式测试
run-v0.5:
	@./qemu-debug.sh v0.5 nographic

run-v0.6:
	@./qemu-debug.sh v0.6 nographic

run-v0.7:
	@./qemu-debug.sh v0.7 nographic

run-v0.8:
	@./qemu-debug.sh v0.8 nographic

run-v0.9:
	@./qemu-debug.sh v0.9 nographic

run-v1.0:
	@./qemu-debug.sh v1.0 nographic
