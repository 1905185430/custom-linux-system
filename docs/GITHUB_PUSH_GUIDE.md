# GitHub 推送指南

## 仓库信息

- **GitHub 用户名**: 1905185430
- **仓库名称**: custom-linux-system
- **仓库地址**: https://github.com/1905185430/custom-linux-system

## 推送步骤

### 方法一：在本地执行推送命令

1. **进入项目目录**
   ```bash
   cd /home/xuan/linux_class
   ```

2. **初始化 GitHub 远程仓库**
   ```bash
   git remote add origin https://github.com/1905185430/custom-linux-system.git
   ```

3. **切换到 main 分支**
   ```bash
   git branch -M main
   ```

4. **推送到 GitHub**
   ```bash
   git push -u origin main
   ```
   
   系统会提示输入用户名和密码：
   - 用户名: `1905185430`
   - 密码: 使用 GitHub Personal Access Token（不是登录密码）

### 方法二：使用 GitHub CLI（推荐）

1. **安装 GitHub CLI**
   ```bash
   # Ubuntu/Debian
   sudo apt install gh
   
   # 或使用 snap
   sudo snap install gh
   ```

2. **登录 GitHub**
   ```bash
   gh auth login
   ```

3. **创建仓库并推送**
   ```bash
   gh repo create custom-linux-system --public --source=. --push
   ```

### 方法三：手动在 GitHub 上创建仓库后推送

1. **在 GitHub 上创建空仓库**
   - 访问 https://github.com/new
   - 仓库名称: `custom-linux-system`
   - 选择 Public（公开）或 Private（私有）
   - **不要**勾选 "Initialize this repository with a README"
   - 点击 "Create repository"

2. **推送现有代码**
   ```bash
   git remote add origin https://github.com/1905185430/custom-linux-system.git
   git branch -M main
   git push -u origin main
   ```

## 获取 GitHub Personal Access Token

由于 GitHub 不再支持密码登录，您需要创建 Personal Access Token：

1. 登录 GitHub
2. 点击右上角头像 → Settings
3. 左侧菜单选择 "Developer settings"
4. 选择 "Personal access tokens" → "Tokens (classic)"
5. 点击 "Generate new token (classic)"
6. 设置：
   - Note: `linux-initrd-builder`
   - Expiration: 选择过期时间（建议 90 天）
   - Scopes: 勾选 `repo`（完整仓库访问权限）
7. 点击 "Generate token"
8. **立即复制生成的 token**（只显示一次）

## 推送命令汇总

```bash
# 进入项目目录
cd /home/xuan/linux_class

# 检查远程仓库
git remote -v

# 添加远程仓库（如果还没有）
git remote add origin https://github.com/1905185430/custom-linux-system.git

# 重命名分支为 main
git branch -M main

# 推送代码
# 会提示输入用户名和 token
git push -u origin main
```

## 验证推送成功

推送完成后，访问：
```
https://github.com/1905185430/custom-linux-system
```

您应该能看到：
- 6 个 commit
- 所有版本文件（initrd0.5, initrd0.6, initrd0.7, initrd1.0）
- README.md
- ISO 镜像文件

## 项目内容概览

推送后，GitHub 仓库将包含：

```
custom-linux-system/
├── README.md                              # 项目说明文档
├── VMware Linux 系统构建教程.md           # 原始教程
├── Custom-Linux-v1.0-ISO-Collection.iso  # ISO 镜像 (650MB)
│
├── initrd0.5.img                          # v0.5 镜像 (4.1MB)
├── initrd0.6.img                          # v0.6 镜像 (45MB)
├── initrd0.7.img                          # v0.7 镜像 (47MB)
├── initrd1.0.img                          # v1.0 镜像 (48MB)
│
├── initrd0.5/                             # v0.5 源码
├── initrd0.6/                             # v0.6 源码
├── initrd0.7/                             # v0.7 源码
├── initrd0.8/                             # v0.8 源码
├── initrd0.9/                             # v0.9 源码
├── initrd1.0/                             # v1.0 源码
│
└── iso_build/                             # ISO 构建目录
    ├── 使用说明-总览.txt
    ├── v0.5-basic/
    ├── v0.6-udev/
    ├── v0.7-systemd/
    └── v1.0-full/
```

## 提交历史

```
8f6be48 添加ISO镜像构建目录和完整文档
229f84f 添加项目README文档
c4bb1c2 v1.0: 完整Linux系统构建完成
8f73e0b v0.7: 集成systemd基础服务
685ae34 v0.6: 集成udev支持
0d2c781 v0.5: 基础initrd构建完成
```

## 后续更新

如果之后有更新，使用以下命令推送：

```bash
# 添加所有更改
git add -A

# 提交更改
git commit -m "更新说明"

# 推送到 GitHub
git push origin main
```

## 注意事项

1. **大文件警告**: ISO 镜像文件 (650MB) 较大，推送可能需要一些时间
2. **Git LFS**: 如果 GitHub 提示大文件限制，可以考虑使用 Git LFS
3. **网络稳定**: 确保网络连接稳定，避免推送中断

## 需要帮助？

如果遇到问题：
1. 检查网络连接
2. 确认 token 权限正确
3. 查看 GitHub 状态: https://www.githubstatus.com/

祝您推送顺利！🚀
