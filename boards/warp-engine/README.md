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
| `WARP_ENGINE_BBS_DB` | `data/warp-engine.sqlite3` | the board's SQLite database: the downloads that went through |

The download log feeds the download count shown with each title. `data/` is a
volume. The log was `data/downloads.jsonl` (one JSON line a download) before
SQLite: on the first start a `downloads.jsonl` next to the database is imported
into the empty table in one transaction (a line that does not parse is skipped
and counted), then renamed to `downloads.jsonl.imported`; the log says how many
rows came over.

The archive is read through rubbs' `Rubbs::Common::Web::HTTP` (a deadline, a byte cap, the
board's User-Agent, public addresses only); a shelf's index is kept in a
`Rubbs::Common::Storage::Cache` for `WARP_ENGINE_BBS_INDEX_TTL` seconds, so callers opening the
same shelf at once share one request, and a dead archive gives the last index
it sent (Reload reads it anew with `Rubbs::Common::Storage::Cache#refresh`, which keeps the old one
when the archive fails). Its lines go through `Rubbs::Common::Text.clean` before they are
shown. The repository raises `Rubbs::Common::Web::HTTP::Error`; the catalog service logs it
and tells the face there is nothing (the rubbs error rule).

Every log line (the board's and rubbs') starts with `warp-engine-bbs:`
(rubbs' `Rubbs.log`, `log_tag`).

## Project structure

```
bbs.rb                      entry point: Rubbs.board (rubbs 2.0 DSL)
config/shelves.yml          the shelves of the archive
lib/domain.rb               requires the domain in dependency order
lib/domain/
  migrations.rb             the schema of the database, one step per version
  model/download_model.rb   the downloads table (Rubbs::Common::Storage::Model) and the counts
  model/shelf_model.rb      a shelf: id, name, folder, about
  model/title_model.rb      a line of INDEX.TXT
  repository/shelf_repository.rb     config/shelves.yml
  repository/archive_repository.rb   INDEX.TXT (cached) and the files, over HTTP
  repository/legacy_download_log.rb  the one-time import of data/downloads.jsonl
  service/catalog_service.rb         shelves, titles, a checked fetch, the log
  warp_engine_bbs.rb        the composition root (WarpEngineBBS, a Rubbs::Common::Board::Domain)
lib/ui/
  wording.rb                why a download cannot go, both faces
  modern.rb                 UI::Modern::APP: commands, menus, help, desktop
  modern/helpers.rb         its helpers: open a shelf, a download, a title's card
  modern/shelves_window.rb  the shelves window
  modern/titles_window.rb   a shelf's titles window and its protocol buttons
  petscii.rb                UI::Petscii: the C64 face (a Rubbs::Petscii::Face)
```

## Tests

The domain (the download table and its legacy import, the archive with its
cache, the index lines, the checked fetch) has minitest tests under `test/`;
they need no network. CI runs them before a deploy.

```bash
bundle exec rake test            # all
bundle exec rake test archive    # the files whose name has the word
```

The downloads are rubbs' `Rubbs::Common::Files::Transfer` (`Rubbs::Common::Files::Zmodem` and `Rubbs::Common::Files::Xmodem`).

## License

MIT, see `LICENSE`.
