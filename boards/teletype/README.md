# Teletype BBS Server

Telnet-accessible Synchronet-style community BBS server built on the
[rubbs](https://git.teletypegames.org/engines/rubbs) gem. Full-screen ANSI interface
with a top menubar, stacked modal windows, message boards, multi-user chat,
news from teletypegames.org, the game catalog and the wiki guides.

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
| `BBS_SYSOPS` | empty | Comma-separated sysop names. Sysop rights need the name's password; these accounts are created only with `bin/account` |
| `BBS_DISCORD_WEBHOOK` | empty | Discord webhook for new board posts and sysop broadcasts; empty = off |
| `ACCOUNTS_PATH` | `data/accounts.csv` | Registered names with salted PBKDF2-SHA256 password hashes |
| `BOARDS_PATH` | `data/boards` | Directory of per-board CSV files |
| `MESSAGES_PATH` | `data/messages.dat` | Legacy single-board file; auto-migrated into the General board on first run |
| `LAST_CALLERS_PATH` | `data/last_callers.csv` | Finished calls (see *Last callers* below) |
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
| **File** | Bulletin · News · System Info · Exit |
| **Messages** | Boards… · New Post… |
| **Files** | Game Catalog · Platform Guides · Engines · DOS Corner |
| **Users** | Online · Last Callers · Team · Profile… · Register… · Language EN/HU |
| **Chat** | Open chat |
| **Doors** | SERMO |
| **Network** | Other systems (our other BBSes and bbsweb) |
| **Sysop** | Console (logged-in sysops only) |
| **Help** | About · Keys |

### Features

- **Multi-board messaging** — separate sub-boards (General / Tech / Off-Topic / Sysop), each in its own CSV file under `data/boards/`.
- **Multi-line composer** — `TextArea` widget, up to 1000 chars per post.
- **Live chat** — broadcast hub, 1 Hz polling, history replay on join.
- **Bulletin on login** — the latest releases and upcoming events from teletypegames.org, plus message count and last callers.
- **News** — the latest releases with catalog links, upcoming events, and the wiki's `blog` posts once there are any (the same source as teletypegames.org/blog).
- **Game catalog** — every catalog entry (all pages of the API), sorted by platform; the **Platform** button cycles a platform filter. The card shows version, release date, the catalog link, the downloadable kinds, and the external links.
- **Wiki sections** — Platform Guides (`/platforms`), Engines (`/engines`) and the DOS Corner (`/dos`, with an FTP/DOSINST intro), read from the Grav JSON API; private pages are left out. Users > Language switches them to Hungarian.
- **Team** — the members of teletypegames.org with their mottos.
- **Doors** — full-line programs the BBS hands the telnet line to and takes it back from when they exit. **SERMO** ([sermo-bbs](https://git.teletypegames.org/bbs/sermo-bbs), pulled in as the `sermo` gem) is a Margittai machine from the Neumatronic universe: type a command, or just talk to it; `EXIT` returns to the BBS. A new door is one entry in `DOORS` plus a menu item.
- **Registered names** — a caller can register the name they logged in with (Users > Register…); from then on that name asks for its password. Profiles belong to registered names only.
- **Sysop console** — stats + broadcast, for names in `BBS_SYSOPS` that logged in with their password.
- **Discord feed** — new board posts and sysop broadcasts go to `BBS_DISCORD_WEBHOOK`, mentions disabled.
- **Last callers** — a call is logged when it ends, and only if the terminal reported its window size (telnet NAWS) and stayed at least 10 seconds. Telnet password-guessing bots never get listed, and neither do they show up as online.
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
    last_callers_repository.rb         finished-call log
    profile_repository.rb              per-user persistent profile
    account_repository.rb              registered names, PBKDF2 hashes
    site_repository.rb                 teletypegames.org events + members
    http_json.rb                       JSON GET + 5-minute cache
  service/
    online_service.rb, board_service.rb, wiki_service.rb,
    games_service.rb, chat_service.rb, last_callers_service.rb,
    profile_service.rb, account_service.rb, site_service.rb,
    discord_notifier.rb
  model/                               value objects (MessageModel, GameModel, …)
  bbs/ui/formatters.rb                 view helpers: bulletin, news, game card,
                                       team, network, DOS intro, users, sysop
data/
  boards/<id>.csv                      per-board messages (auto-created)
  last_callers.csv                     finished calls
  profiles.csv                         persistent user profiles
  accounts.csv                         registered names (mode 600)
bin/account                            create an account / reset a password
```

### Sysop accounts

Names in `BBS_SYSOPS` cannot be registered over telnet, so nobody can take one
first. Create the account (or reset any password) from the server shell:

```bash
docker exec -it teletype-bbs bin/account Tasi
```

## Data

All persisted state lives under `data/` which is mounted as a volume in Docker
so it survives container restarts.
