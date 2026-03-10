# Teletype BBS Server

A modern, Go-based Bulletin Board System (BBS) server designed for Telnet access. It features community tools, wiki integration, and a game catalog, all rendered with retro-style ANSI graphics.

## Quick Start

### Prerequisites
- [Go](https://go.dev/dl/) 1.26 or higher
- A [Wiki.js](https://wiki.js.org/) instance (optional, for Wiki features)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd bbs-server
   ```

2. Install dependencies:
   ```bash
   go mod download
   ```

3. Set up environment variables (optional but recommended for Wiki access):
   ```bash
   export WEBAPP_WIKIJS_TOKEN="your-wiki-js-api-token"
   ```

4. Run the server:
   ```bash
   go run main.go
   ```

The server starts on `0.0.0.0:2323` by default.

### Connecting
You can connect to the BBS using any standard Telnet client:
```bash
telnet localhost 2323
```

## Configuration

- **Host/Port:** Currently hardcoded in `main.go` for simplicity.
- **Wiki API:** Configured in `lib/repository.wiki.go`.
- **Games API:** Configured in `lib/repository.catalog.go`.
- **Internationalization:** Text is managed in `lib/sys.i18n.go` using a map-based system.

## Project Structure

- `main.go`: Entry point and network listener.
- `lib/`: Core logic and modules.
  - `repository.*.go`: Data fetching from external APIs (Wiki, Games).
  - `menu.*.go`: Logic for individual BBS sections.
  - `sys.print.go`: Telnet-specific I/O and ANSI rendering.
  - `sys.header.go`: Core state and UI layouts.
  - `sys.i18n.go`: Translation maps.

## Development

To build a production binary:
```bash
go build -o bbs-server main.go
```

To run with Docker:
```bash
docker-compose up --build
```
