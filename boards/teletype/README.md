# Teletype BBS Server

Telnet-accessible Synchronet-style community BBS server built on the
[rubbs](https://git.teletype.hu/tools/rubbs) gem. Full-screen ANSI interface
with a top menubar, stacked modal windows, message boards, multi-user chat,
wiki integration, and a game catalog.

## Running

**Docker Compose:**

```bash
docker compose up --build
```

**Directly (Ruby 3.x):**

```bash
bundle install
ruby bbs.rb
```

Connect:

```bash
telnet localhost 2323
```

## Configuration

Copy `env-example` to `.env`:

| Variable | Default | Description |
|---|---|---|
| `BBS_PORT` | `2323` | TCP port to listen on |
| `BBS_SYSOPS` | empty | Comma-separated list of usernames with sysop access |
| `BOARDS_PATH` | `data/boards` | Directory of per-board CSV files |
| `MESSAGES_PATH` | `data/messages.dat` | Legacy single-board file; auto-migrated into the General board on first run |
| `LAST_CALLERS_PATH` | `data/last_callers.csv` | Login log CSV |
| `PROFILE_PATH` | `data/profiles.csv` | User profile CSV |
| `BBS_DESKTOP_ART` | `data/art` | Path to a single ANSI art file (`.ans`, `.ansi`, `.asc`, `.nfo`, `.txt`) **or** a directory containing them — a random one is shown per session. CP437 / SAUCE-aware |

## Interface

Connect, type a name at the prompt, then a full-screen Synchronet-style shell
opens.

### Keys

| Key | Action |
|---|---|
| `Alt+letter` | Open the matching top menu |
| `F10` | Open the leftmost menu |
| `Tab` / `Shift-Tab` | Move focus inside a window |
| `Enter` | Activate the focused button / submit input |
| `Esc` | Close the top window / menu |
| `F1` | Help |
| `F2` | Message Boards |
| `F3` | Quick post |
| `F4` | Chat |

### Menus

| Menu | Items |
|---|---|
| **File** | Bulletin · System Info · Exit |
| **Messages** | Boards… · New Post… |
| **Files** | Blog Posts · HowTo Guides · Game Catalog |
| **Users** | Online · Last Callers · Profile… |
| **Chat** | Open chat |
| **Sysop** | Console (sysops only) |
| **Help** | About · Keys |

### Features

- **Multi-board messaging** — separate sub-boards (General / Tech / Off-Topic / Sysop), each in its own CSV file under `data/boards/`.
- **Multi-line composer** — `TextArea` widget, up to 1000 chars per post.
- **Live chat** — broadcast hub, 1 Hz polling, history replay on join.
- **Wiki split-view** — list of titles on the left, selected page rendered on the right.
- **Game card** — selected game's story + external links.
- **Last callers** + **online users** + **bulletin on login** (last callers, message count).
- **Persistent user profile** — signature / location / homepage / notes per username.
- **Sysop console** — stats + broadcast (only for users in `BBS_SYSOPS`).
- **xterm mouse** — click menus, buttons, list items; wheel-scroll lists.
- **Idle disconnect** at 10 minutes.
- **Configurable desktop art** — drop `.ans` / `.ansi` / `.asc` / `.nfo` / `.txt` files into `data/art/` (or wherever `BBS_DESKTOP_ART` points). Classic CP437 BBS art is auto-decoded; SAUCE metadata is stripped. With a directory, a different file is shown per session.

## Project structure

```
bbs.rb                                 entry point — services + Application
lib/
  repository/
    online_users_repository.rb         thread-safe connected-user map
    board_repository.rb                multi-board CSV store
    wiki_repository.rb                 Grav wiki JSON client
    catalog_repository.rb              games API client
    last_callers_repository.rb         login log
    profile_repository.rb              per-user persistent profile
  service/
    online_service.rb, board_service.rb, wiki_service.rb,
    games_service.rb, chat_service.rb, last_callers_service.rb,
    profile_service.rb
  model/                               value objects (MessageModel, GameModel, …)
  ui/windows/                          per-window builders (messages, wiki,
                                       games, users, chat, bulletin, profile,
                                       sysop, system info)
data/
  boards/<id>.csv                      per-board messages (auto-created)
  last_callers.csv                     login log
  profiles.csv                         persistent user profiles
```

## Data

All persisted state lives under `data/` which is mounted as a volume in Docker
so it survives container restarts.
