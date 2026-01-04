# WebSidecar

A monorepo project containing a Swift backend for screen streaming and a React frontend for viewing the stream.

## Structure

- `packages/backend`: Swift server using ScreenCaptureKit and MJPEG streaming.
- `packages/frontend`: React + Vite + Ant Design application.

## Prerequisites

- macOS 12.3+ (for ScreenCaptureKit)
- Swift installed
- Node.js installed

## Getting Started

### 1. Start the Backend

Run the Swift backend server:

```bash
npm run start:backend
```

Or directly:

```bash
swift packages/backend/main.swift
```

The server will start on port `65532`.

### 2. Start the Frontend

In a separate terminal, start the React frontend:

```bash
npm install
npm run start:frontend
```

The frontend will be available at `http://localhost:5173`.

## Features

- **Backend**:
  - Lists available displays.
  - Streams display content using MJPEG.
  - REST API for display information.
  - CORS support.

- **Frontend**:
  - Lists displays with resolution information.
  - View live stream of selected display.
  - Fullscreen mode support.
  - Clean UI with Ant Design.
