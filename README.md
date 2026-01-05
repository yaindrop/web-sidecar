# WebSidecar

A lightweight, powerful tool to turn any browser into a secondary display for your Mac.

WebSidecar runs a local server on your Mac that streams your display content to any device on your local network via a web browser. It is built with a modular architecture featuring a high-performance Swift backend and a modern React frontend, packaged into a native macOS menu bar application.

## Installation and Usage

### Instructions for Users

If you have downloaded the pre-built application (e.g., from GitHub Releases), you must bypass the macOS Gatekeeper security check because the app is locally signed and not notarized by Apple.

1. Unzip the app.
2. Open Terminal and navigate to the app's directory.
3. Run the following command to remove the quarantine attribute:
   ```bash
   xattr -cr ./WebSidecar.app
   ```
4. Open the app normally.
5. The app will appear in your menu bar. Click the icon to open the web interface.

### Configuration

You can adjust settings (such as resolution and video quality) directly via the **Web UI**. Changes made in the UI are saved automatically.

**Advanced Configuration:**

For manual overrides or headless setup, the application loads configuration from the following locations (in order of priority):

1. Environment Variable: `WEBSIDECAR_CONFIG=/path/to/config.json`
2. Local Directory: `./config.json` (useful for CLI dev)
3. User Config: `~/Library/Application Support/com.yaindrop.websidecar/config.json` (Default for App)

**Default Config:**
```json
{
  "maxDimension": 1920,
  "videoQuality": 0.75
}
```

## Project Structure

This project is a monorepo managed with `pnpm`:

- **packages/backend**: A Swift library and CLI tool.
  - Uses `ScreenCaptureKit` for high-performance, low-latency screen recording.
  - Implements an MJPEG streaming server using SwiftNIO.
  - Serves REST API for display management and configuration.
- **packages/frontend**: A React + Vite Single Page Application (SPA).
  - Provides a clean UI to view streams and manage settings.
  - Uses Ant Design and Tailwind CSS for styling.
- **packages/macos**: A native macOS menu bar application (SwiftUI).
  - Embeds the backend server directly.
  - Serves the compiled frontend as static files.
  - Provides system integration (Menu bar icon, "Open at Login", etc.).

## Development

### Prerequisites

- macOS 13.0+ (Required for ScreenCaptureKit)
- Xcode 14+ (for Swift tooling)
- Node.js 18+ and pnpm

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yaindrop/web-sidecar.git
   cd web-sidecar
   ```

2. Install dependencies:
   ```bash
   pnpm install
   ```

### Running the Application

#### Option A: Native macOS App (Recommended)

This builds the full standalone application that runs in your menu bar.

1. Build the application:
   ```bash
   pnpm build:app
   ```
   This command automatically builds the frontend and packages the macOS application.

2. Run the app:
   ```bash
   open packages/macos/.build/release/WebSidecar.app
   ```

#### Option B: Development Mode

Run the backend CLI and frontend development server independently for rapid development.

```bash
pnpm dev
```

- Backend runs on http://localhost:65532
- Frontend runs on http://localhost:5173

### Building for Distribution

The `bundle_app.sh` script creates a locally signed application using ad-hoc signing.

**Sharing via GitHub:**
If you upload the built `.app` (zipped) to GitHub, other users can download it, but they will encounter macOS Gatekeeper security warnings as described in the "Installation and Usage" section.

### Tech Stack

- **Swift**: Backend logic, HTTP Server, ScreenCaptureKit, SwiftUI.
- **React**: Frontend UI, Video Player.
- **Vite**: Frontend tooling.
- **pnpm**: Package management.

## License

MIT
