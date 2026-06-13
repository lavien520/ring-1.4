# RingGlow

Claude Code 智能体状态的可视化指示器 — 一个悬浮在桌面上的发光环形动画。

[![最新版本](https://img.shields.io/github/v/release/lavien520/ring-1.4?label=最新版本)](https://github.com/lavien520/ring-1.4/releases/latest)
[![下载安装程序](https://img.shields.io/github/downloads/lavien520/ring-1.4/total?label=下载次数)](https://github.com/lavien520/ring-1.4/releases/latest)

## ✨ 功能特性

- **实时状态监控** — 显示 Claude Code 智能体状态（空闲、思考中、工作中、需关注、错误、休眠、通知）
- **视觉反馈** — 带发光效果的动画环形，支持颜色变化和旋转动画
- **权限提醒** — 当 Claude Code 请求工具权限时，显示允许/拒绝按钮
- **内存监控** — 在环形中心显示当前内存使用百分比
- **重力物理** — 拖拽释放后环形会遵循物理效果弹跳
- **粒子球模式** — 另一种外观，包含 3000 个动画粒子
- **自定义设置** — 可调节环形大小、发光强度和外观模式
- **全屏感知** — 全屏应用激活时自动隐藏

## 📦 安装

### 方式一：下载 DMG 安装程序（推荐）

1. 前往 [GitHub Releases](https://github.com/lavien520/ring-1.4/releases) 下载最新版本
2. 打开 `RingGlow-1.0.dmg`
3. 将 `RingGlow.app` 拖入 `Applications` 文件夹
4. 启动应用，桌面上会出现一个发光环形

### 方式二：从源码构建

```bash
git clone https://github.com/lavien520/ring-1.4.git
cd ring-1.4
make install    # 构建 + 自动安装 Hook + 启动应用
```

> `make install` 会自动配置 Claude Code Hook，无需手动操作。首次安装推荐使用此命令。

## 🎮 使用方法

- **左键拖拽** — 移动环形位置
- **右键点击** — 打开上下文菜单，包含以下选项：
  - 设置（调整环形大小）
  - 旋转 / 自旋动画
  - 发光强度调节
  - 内存使用显示
  - 粒子脉冲效果
  - 外观模式切换（环形 / 粒子球）
  - 退出

## ⚙️ 配置

环形通过本地 HTTP 服务器（端口 23334）与 Claude Code 的 Hook 系统通信。

安装 Hook 脚本：

```bash
cd hooks
./install-hooks.sh
```

## 📋 系统要求

- macOS 13.0 (Ventura) 或更高版本
- 已安装 Claude Code CLI

## 🛠️ 构建命令

```bash
make install     # 构建 + 自动安装 Hook + 启动（推荐首次安装）
make build       # 仅构建应用（已配置 Hook 时自动跳过安装）
make run         # 构建并运行
make dmg         # 生成 DMG 安装程序
make dmg-simple  # 生成简单 DMG（无自定义界面）
make clean       # 清理构建目录
```

## 📄 许可证

MIT License

## 💡 为什么选择 RingGlow？

- **不干扰工作** — 悬浮在桌面上，不遮挡内容
- **美观精致** — 流畅的动画和发光效果
- **信息直观** — 一眼就能看到 Claude Code 的状态
- **高度可定义** — 根据个人喜好调整
- **全屏友好** — 全屏时自动隐藏
