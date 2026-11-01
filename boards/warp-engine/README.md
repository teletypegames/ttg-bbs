# WarpEngine BBS

The file area of Teletype Games on a telnet line. The WarpEngine of
[teletypegames.org](https://teletypegames.org) keeps shelves for machines
without a web browser on the archive's plain HTTP
(`http://archive.teletypegames.org`); this board lends them out: pick a shelf,
pick a title, and take it home by ZMODEM or XMODEM. It is the telnet sibling of
[WARP64U](https://git.teletypegames.org/stores/warp64u), the store that runs on
the C64 itself.

It has two faces on one port, like every board of the network:

- a **modern** one for ANSI terminals: the shelves and the titles in two-pane
  windows, and a download by **ZMODEM** (SyncTERM, NetRunner, Qodem, the web
  terminal of bbsweb start it by themselves), **XMODEM-1K** or **XMODEM**;
- a **Commodore 64** one in PETSCII, 40×25: numbered lists, a page a title, and
  a download by **XMODEM-1K** or **XMODEM**, the protocols a C64 terminal
  (CCGMS, Novaterm, UltimateTerm) knows. The caller starts the download in the
  terminal and names the file; it lands on the disk as a program.

The shelves are the Commodore 64 one (`/C64`) and the Plus/4 one (`/PLUS4`),
listed in `config/shelves.yml`. Each has an `INDEX.TXT` in the shelf format of
the WarpEngine (`#SHELF 1`, `file|version|size|crc32|title|author|description`).
A file goes out only when its size and CRC-32 match its index line.

XMODEM fills its last block up with SUB bytes, so the received file can be
longer by up to 127 (XMODEM) or 1023 (XMODEM-1K) bytes. A Commodore program
loads all the same.

## Running

**Docker Compose:**

```bash
docker compose up --build
```

**Directly (Ruby 3.x):**

```bash
bundle install
BBS_PORT=2329 bundle exec ruby bbs.rb
```

Then `telnet localhost 2329`. Every environment variable is in `env-example`
with its default. The board has no secrets.

| Variable | Default | |
|---|---|---|
| `WARP_ENGINE_BBS_ARCHIVE_URL` | `http://archive.teletypegames.org` | the archive's plain HTTP |
| `WARP_ENGINE_BBS_SHELVES` | `config/shelves.yml` | the shelves and their folders |
| `WARP_ENGINE_BBS_INDEX_TTL` | `300` | seconds a shelf's `INDEX.TXT` is kept |
| `WARP_ENGINE_BBS_DOWNLOAD_MAX` | `1048576` | the largest file sent, in bytes |
| `WARP_ENGINE_BBS_DOWNLOADS` | `data/downloads.jsonl` | the downloads that went through, one JSON line each |

The download log feeds the download count shown with each title. `data/` is a
volume.

## Project structure

```
bbs.rb                      entry point: BBS.configure + BBS::Terminal.flow
config/shelves.yml          the shelves of the archive
lib/domain.rb               requires the domain in dependency order
lib/domain/
  model/shelf_model.rb      a shelf: id, name, folder, about
  model/title_model.rb      a line of INDEX.TXT
  repository/shelf_repository.rb     config/shelves.yml
  repository/archive_repository.rb   INDEX.TXT (cached) and the files, over HTTP
  repository/download_repository.rb  data/downloads.jsonl and the counts
  service/catalog_service.rb         shelves, titles, a checked fetch, the log
  warp_engine_bbs.rb        the composition root (WarpEngineBBS)
lib/ui/
  transfer.rb               the protocols and what the caller is told, both faces
  logo.rb                   WARP in blocks (BBS::BlockFont), both faces
  modern.rb                 UI::Modern: the rubbs Application
  petscii.rb                UI::Petscii: the C64 board
  petscii/screen.rb         the 40×25 screen: rubbs' BBS::Petscii::Screen
```

The downloads are rubbs' `BBS::Zmodem` and `BBS::Xmodem` (rubbs 0.26.0 and
later).

## License

MIT, see `LICENSE`.
