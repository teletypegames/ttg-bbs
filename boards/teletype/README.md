# Teletype BBS Server

Telnet-accessible community BBS server built on the [rubbs](https://git.teletype.hu/tools/rubbs) gem. ANSI-rendered retro terminal interface with a message board, wiki integration, and a game catalog.

## Running

**Docker Compose (recommended):**

```bash
docker compose up --build
```

**Directly (requires Ruby 3.x):**

```bash
bundle install
ruby bbs.rb
```

Connect with:

```bash
telnet localhost 2323
```

## Configuration

Copy `env-example` to `.env` and fill in the values:

| Variable | Default | Description |
|---|---|---|
| `WEBAPP_WIKIJS_TOKEN` | — | Bearer token for Wiki.js API (optional) |
| `MESSAGES_PATH` | `data/messages.dat` | Path to the messages CSV file |

## Menu

| Option | Description |
|---|---|
| Message Board | View the last 30 messages |
| New Message | Post a message (max 200 chars) |
| Blog Posts | Browse blog entries from Wiki.js |
| HowTo Guides | Browse how-to articles from Wiki.js |
| Game Catalog | Browse the Teletype game catalog |
| Online Users | List of currently connected users |
| System Info | Server stats |

## Project structure

```
bbs.rb              Entry point — BBS configuration and flow definition
lib/
  online_users.rb   Thread-safe connected-users map
  message_board.rb  CSV-backed message store
  wiki.rb           Wiki.js GraphQL client
  catalog.rb        Games API client
  display.rb        ANSI rendering helpers and content handlers
data/
  messages.dat      Message board records (auto-created)
```

## Data

Messages are stored in `data/messages.dat` (plain CSV, auto-created on first post). The `data/` directory is mounted as a Docker volume so records survive container restarts.
