<p align="center">
  <img src="favicon.png" width="100" />
</p>

# WebSidecar

A lightweight, powerful tool to turn any browser into a secondary display for your Mac.

WebSidecar runs a local server on your Mac that streams your display content to any device on your local network via a web browser. It's built with a modular architecture featuring a high-performance Swift backend and a modern React frontend, packaged into a native macOS menu bar application.

## 🏗 Project Structure

This project is a monorepo managed with `pnpm`:

- **`packages/backend`**: A Swift library and CLI tool.
  - Uses `ScreenCaptureKit` for high-performance, low-latency screen recording.
  - Implements an MJPEG streaming server using SwiftNIO.
  - Serves REST API for display management and configuration.
- **`packages/frontend`**: A React + Vite Single Page Application (SPA).
  - Provides a clean UI to view streams and manage settings.
  - Uses Ant Design for a polished look.
- **`packages/macos`**: A native macOS menu bar application (SwiftUI).
  - Embeds the backend server directly.
  - Serves the compiled frontend as static files.
  - Provides system integration (Menu bar icon, "Open at Login", etc.).

## 🚀 Getting Started

### Prerequisites

- **macOS 13.0+** (Required for ScreenCaptureKit)
- **Xcode 14+** (for Swift tooling)
- **Node.js 18+** & **pnpm**

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yaindrop/web-sidecar.git
    cd web-sidecar
    ```

2.  **Install dependencies:**
    ```bash
    pnpm install
    ```

### 🏃 Running the App

#### Option A: Native macOS App (Recommended)
This builds the full standalone application that runs in your menu bar.

```bash
# Build the frontend first
pnpm --filter @websidecar/frontend build

# Build and package the macOS app
cd packages/macos
./bundle_app.sh

# Run the app
open .build/release/WebSidecar.app
```
The app will appear in your menu bar. Click the icon to open the web interface.

#### Option B: Development Mode (CLI + Web)
Run the backend CLI and frontend dev server independently for rapid development.

```bash
# Run both backend and frontend concurrently
pnpm dev
```
- Backend runs on `http://localhost:65532`
- Frontend runs on `http://localhost:5173`

## ⚙️ Configuration

The application automatically loads configuration from the following locations (in order of priority):

1.  **Environment Variable**: `WEBSIDECAR_CONFIG=/path/to/config.json`
2.  **Local Directory**: `./config.json` (useful for CLI dev)
3.  **User Config**: `~/Library/Application Support/com.yaindrop.websidecar/config.json` (Default for App)

**Default Config:**
```json
{
  "maxDimension": 1920,
  "videoQuality": 0.75
}
```

## � Distribution

The `bundle_app.sh` script creates a locally signed application using ad-hoc signing.

**Sharing via GitHub:**
If you upload the built `.app` (zipped) to GitHub, other users can download it, but they will encounter macOS Gatekeeper security warnings because the app is not notarized by Apple.

**Instructions for Users:**
To run the app downloaded from GitHub, users must bypass the Gatekeeper check:

1.  Unzip the app.
2.  Open Terminal.
3.  Run the following command to remove the quarantine attribute:
    ```bash
    xattr -cr /path/to/WebSidecar.app
    ```
4.  Open the app normally.

## �🛠 Tech Stack

- **Swift**: Backend logic, HTTP Server, ScreenCaptureKit, SwiftUI.
- **React**: Frontend UI, Video Player.
- **Vite**: Frontend tooling.
- **pnpm**: Package management.

## 📝 License

MIT
