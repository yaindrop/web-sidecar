<div align="center">
  <img src="favicon.png" width="128" alt="WebSidecar Logo" />
</div>

# WebSidecar

[English](README.md) | **简体中文**

**将任何浏览器变成 Mac 的第二块屏幕。**

WebSidecar 在您的 Mac 上运行本地服务器，以低延迟将屏幕内容流式传输到局域网内的任何设备（通过浏览器）。该项目采用模块化架构，融合了高性能的 **Swift** 后端 ⚡ 和现代化的 **React** 前端 ⚛️，打包为原生 macOS 菜单栏应用。

> 特别感谢 **[咩Display](https://github.com/zanjie1999/meDisplay)** 给予的灵感启发！

## 🚀 安装与使用

> ⚠️ **兼容性说明**：此应用程序需要 **macOS 13+**。目前主要在运行 **macOS 26.2** 的 **MacBook Pro M1 Pro** 上进行了测试。

### 📥 用户使用说明

如果您下载了预构建的应用（例如从 GitHub Releases 下载），可能会看到安全警告，因为该应用尚未经过 Apple 公证。

1. **右键点击**（或按住 Control 点击）`WebSidecar.app` 文件，选择 **打开**。
2. 在出现的对话框中，再次点击 **打开** 确认运行应用。
3. 应用将出现在菜单栏中，点击图标即可打开网页界面。

### 💡 虚拟显示器小贴士

为获得真正的第二显示器体验（而不仅仅是镜像），推荐使用 **[DeskPad](https://github.com/Stengo/DeskPad/)**。它可在您的 Mac 上创建虚拟显示器，WebSidecar 可流式传输其内容，为您提供可移动窗口的独立工作区。

### ⚙️ 配置

您可直接通过 **Web UI** 调整设置（如分辨率、视频质量）。更改会自动保存。

**🛠️ 高级配置：**

如需手动覆盖或无头模式（headless）设置，应用按以下优先级加载配置：

1. `环境变量`：`WEBSIDECAR_CONFIG=/path/to/config.json`
2. `本地目录`：`./config.json`（CLI 开发用）
3. `用户配置`：`~/Library/Application Support/com.yaindrop.websidecar/config.json`（App 默认路径）

**默认配置：**

```json
{
  "maxDimension": 1920,
  "videoQuality": 0.75,
  "targetFps": 60,
  "dropFramesWhenBusy": true
}
```

## 🏗️ 项目结构

本项目是一个使用 `pnpm` 管理的 monorepo：

- 📦 **packages/backend**: Swift 库和命令行工具
  - 采用 `ScreenCaptureKit` 实现高性能、低延迟屏幕录制
  - 基于 SwiftNIO 构建 MJPEG 流媒体服务器
  - 提供 REST API 用于管理和配置
- 🎨 **packages/frontend**: React + Vite 单页应用 (SPA)
  - 提供简洁 UI 用于查看流媒体和管理设置
  - 使用 Ant Design 和 Tailwind CSS 进行样式设计
- 🍎 **packages/macos**: 原生 macOS 菜单栏应用 (SwiftUI)
  - 直接嵌入后端服务器
  - 提供编译后的前端静态文件
  - 提供系统集成（菜单栏图标、开机自启等）

## 👨‍💻 开发

### 📋前置要求

- macOS 13.0+（需要 ScreenCaptureKit）
- Xcode 14+（Swift 工具链）
- Node.js 18+ 和 pnpm

### 🛠️ 设置

1. 克隆仓库：

   ```bash
   git clone https://github.com/yaindrop/web-sidecar.git
   cd web-sidecar
   ```

2. 安装依赖：
   ```bash
   pnpm install
   ```

### 🏃 运行应用程序

#### 选项 A：原生 macOS 应用（推荐）

构建在菜单栏运行的独立应用。

1. 构建：

   ```bash
   pnpm build:app
   ```

   _自动构建前端并打包 macOS 应用_

2. 运行：
   ```bash
   open packages/macos/.build/release/WebSidecar.app
   ```

#### 选项 B：开发模式

独立运行后端 CLI 和前端开发服务器，便于快速开发。

```bash
pnpm dev
```

- 🔌 后端：http://localhost:9327
- 🖥️ 前端：http://localhost:5173

### 📦 构建分发版本

`bundle_app.sh` 脚本会创建使用 ad-hoc 签名的本地应用。

**通过 GitHub 分享：**
上传的 `.app` 压缩包会触发 macOS Gatekeeper 警告（参见"用户使用说明"）。

### ⚡ 技术栈

- 🐦 **Swift**: 后端逻辑、HTTP 服务器、ScreenCaptureKit、SwiftUI
- ⚛️ **React**: 前端 UI、视频播放器
- ⚡ **Vite**: 前端工具链
- 📦 **pnpm**: 包管理

## 🤖 AI 辅助构建

本项目的代码约 95% 由 **[Trae](https://trae.ai)** 编写。

## 📄 许可证

MIT
