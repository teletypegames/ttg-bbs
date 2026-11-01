# Commodex BBS

The Commodore 64 game compendium on a telnet line: search titles, read about
them, and trade cheats and tips. A board of the Teletype Games BBS network,
powered by [rubbs](https://git.teletypegames.org/engines/rubbs).

It has two faces on one port, like every board of the network:

- a **modern** one for ANSI terminals: a desktop under a menubar, the search in
  a dialog, lists of games with the card of the picked one on the right, the
  Wikipedia lead in a scrolling window, the tips of a game, and a form for a
  new tip;
- a **Commodore 64** one in PETSCII, 40×25: cursor menus of rubbs
  (`BBS::Selector`: CRSR and RETURN, or the key or number as before) for the
  main menu, the lists and a game's actions, a page a game, pages that wait
  for RETURN, a line for the search and an editor line for a tip.

## Where the data comes from

- **The catalog** is [Wikidata](https://www.wikidata.org)'s, under CC0: every
  item on the platform Commodore 64 (P400 = Q99775) that is a video game
  (P31/P279\* Q7889), about 2,900 of them. Per game: the QID, the English label
  (else another language's), the first publication year (P577; the date given
  for the C64 when there is one, else the earliest), publishers (P123),
  developers (P178), designers (P287), composers (P86), genres (P136), game
  modes (P404), series (P179) and the English Wikipedia article.
  A snapshot ships with the board (`config/catalog.json.gz`, written by
  `bin/refresh-catalog`). The running board reads Wikidata again when its
  copy is older than `COMMODEX_BBS_CATALOG_TTL` (a week) and keeps the result in
  `data/catalog.json.gz`; a failed refresh keeps the previous snapshot and
  tries again an hour later, and so does a refresh that raises: the refresh
  thread logs it and goes on. The queries are POSTs through rubbs'
  `BBS::HTTP` (a deadline, a body cap, the board's User-Agent).
- **About** is the lead of the game's English Wikipedia article, fetched on
  demand through the Action API's extracts (`BBS::HTTP`, at most 5 requests
  a second for all callers together, the same `WikipediaClient` as Alexandria
  BBS) and kept in a `BBS::Cache` of 200 leads and 4 MiB.
  It is shown with "Text from Wikipedia, CC BY-SA 4.0" and the article's
  address.
- **Cheats and tips** are the callers'. A new tip is pending until an admin
  approves it; only approved tips are shown. A caller may send three tips an
  hour, one every 30 seconds, and the board takes at most 30 an hour; callers
  are counted by address (`BBS::RateLimit.caller_key`), so calling again does
  not reset it.

Everything from Wikidata and Wikipedia, and every tip, is cleaned of control
characters (`BBS::Text.clean`) before it reaches a screen.

GameBase64 data is not used: its licence does not allow public use without
the GB64 Team's permission.

## Running

**Docker Compose:**

```bash
docker compose up --build
```

**Directly (Ruby 3.3):**

```bash
bundle install
BBS_PORT=2331 bundle exec ruby bbs.rb
```

Then `telnet localhost 2331`. Every environment variable is in `env-example`
with its default.

| Variable | Default | |
|---|---|---|
| `COMMODEX_BBS_CATALOG_SEED` | `config/catalog.json.gz` | the snapshot shipped with the image |
| `COMMODEX_BBS_CATALOG` | `data/catalog.json.gz` | the snapshot a refresh writes |
| `COMMODEX_BBS_CATALOG_TTL` | `604800` | seconds before Wikidata is read again; `0` never |
| `COMMODEX_BBS_WIKIPEDIA_CACHE` | `200` | Wikipedia leads kept in memory |
| `COMMODEX_BBS_TIPS_DB` | `data/tips.sqlite3` | the tips |
| `COMMODEX_BBS_TIPS_SEED` | `config/tips.yml` | tips shipped with the board, approved from the start |
| `COMMODEX_BBS_DISCORD_WEBHOOK` | *(empty: off)* | rung for every new tip; a secret, in `.env` on the server |

`data/` is a volume. `data/tips.sqlite3` is opened with rubbs' `BBS::SQLite` and its
schema migrated by version (`PRAGMA user_version`): version 1 is the schema the board
created before it had versions, so an older file only gets its version and keeps its tips.

## Tests

```bash
bundle exec rake test
```

Minitest, no network (`BBS::HTTP` is stubbed): the tips table and its migration from a
file without a version, the tip rules and limits, the catalog's search, browse and refresh
round, the game records, the Wikipedia and Wikidata repositories. CI runs them before a
deploy.

## Admin

```bash
docker exec commodex-bbs bin/tips list           # the pending tips
docker exec commodex-bbs bin/tips approved       # the approved ones
docker exec commodex-bbs bin/tips approve ID     # shown from now on
docker exec commodex-bbs bin/tips reject ID      # never shown
bin/refresh-catalog [path]                   # a new seed from Wikidata (in a dev checkout)
```

## Project structure

```
bbs.rb                      entry point: BBS.configure + BBS::Terminal.flow
bin/tips                    the admins' tool for the tips
bin/refresh-catalog         writes the seed catalog from Wikidata
config/catalog.json.gz      the seed catalog (Wikidata, CC0)
config/tips.yml             verified tips shipped with the board (empty)
lib/domain.rb               requires the domain in dependency order
lib/domain/
  model/game_model.rb       a game: QID, title, year, article, the name lists
  model/tip_model.rb        a tip and its status
  model/summary_model.rb    a Wikipedia lead
  repository/catalog_repository.rb    the snapshot files, the games in memory
  repository/wikidata_repository.rb   the SPARQL queries
  repository/wikipedia_client.rb      the Action API over BBS::HTTP, paced
  repository/wikipedia_repository.rb  article leads, cached (BBS::Cache)
  repository/tip_repository.rb        the tips table (BBS::SQLite), its migrations
  repository/tip_seed_repository.rb   config/tips.yml
  service/catalog_service.rb          search, years, genres, companies, the refresh
  service/about_service.rb            a game's Wikipedia lead
  service/tip_service.rb              tips: submit, limits, approve, reject
  service/discord_notifier.rb         a new tip on Discord (BBS::DiscordWebhook)
  commodex_bbs.rb           the composition root (CommodexBBS)
lib/ui/
  logo.rb                   COMMODEX in blocks (BBS::BlockFont), both faces
  words.rb                  a game's facts and the messages, both faces
  modern.rb                 UI::Modern: the rubbs Application and its parts
  modern/helpers.rb         search, the lists, about, tips, the desktop
  modern/menu.rb            the menubar, the status bar's hints, the desktop on start
  modern/pane.rb            the frame of the list windows
  modern/card.rb            a game's card in the games window
  modern/games_window.rb, groups_window.rb, letters_window.rb, about_window.rb,
  modern/tips_window.rb, add_tip_window.rb     one module per window
  petscii.rb                UI::Petscii: the masthead, the flow, goodbye
  petscii/screen.rb         the 40×25 screen: rubbs' BBS::Petscii::Screen
  petscii/board.rb          the C64 board: menu, lists, game page, tips
test/                       minitest tests of the domain
Rakefile                    rake test
```

## Licence

MIT, see `LICENSE`. The catalog data is Wikidata's (CC0); the Wikipedia text
shown on the board is under CC BY-SA 4.0.
