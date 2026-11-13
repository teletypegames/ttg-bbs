# Siliconia BBS

The computer and console museum on a telnet line: every home computer, microcomputer, personal
computer and video game console Wikidata knows, with its maker, years, CPU and memory, its family
line and the Wikipedia story. Callers mark the machines they had and write down what they remember
of them. A board of the Teletype Games BBS network, powered by
[rubbs](https://git.teletypegames.org/engines/rubbs).

It has two faces on one port, like every board of the network:

- a **modern** one for ANSI terminals: a desktop under a menubar, the shelves as lists with the
  picked machine's card on the right, a machine's page in a reader with its buttons (Wiki, HU,
  Photo, Family, CPU, Memories, Mine), the Wikipedia lead in a scrolling window, the photo in half
  blocks, two machines side by side (Museum > Compare two), the memories and their form;
- a **Commodore 64** one in PETSCII, 40×25: cursor menus, numbered lists, a page a machine with
  its actions on one row (wiki, photo, more) and the rest under "more", the Wikipedia lead and the
  memories as pages, the photo on a screen of its own, a line for a search, a comparison and a
  memory.

## Where the data comes from

- **The catalog** is [Wikidata](https://www.wikidata.org)'s, under CC0. Wikidata describes a
  machine model as a class (the Commodore 64 is a subclass of home computer), so a machine is every
  item under home computer (Q473708), microcomputer (Q32738), personal computer (Q16338) or video
  game console (Q8076, handhelds Q941818) by P31 or P279, about 3,400 of them. Left out: the roots,
  items that are a class of computers, a form factor, a video game, software, a fantasy console, an
  open-source project or a sequence, and bare categories (no P31, and other items are their
  subclasses). Per machine: the QID, the name (English, else another language's) and the Hungarian
  one, the kind, the year (publication P577, else inception P571) and discontinuation (P2669), the
  English and Hungarian Wikipedia articles, makers (P176) and their countries, CPUs (P880),
  operating systems (P306), country of origin (P495), memory (P2928 with its unit), units sold
  (P2664), the number of games on it (P400 backwards), and the machines before and after it
  (P155/P156, kept when they are in the catalog).
  The first queries gather the items, one a root; the facts then come in VALUES blocks of 300
  items, so no query nears the endpoint's 60 seconds (a whole refresh takes about two minutes).
  A snapshot ships with the board (`config/catalog.json.gz`, written by `bin/refresh-catalog`);
  the running board reads Wikidata again when its copy is older than `SILICONIA_BBS_CATALOG_TTL`
  (a week) and keeps it in `data/catalog.json.gz`. A failed refresh is logged, keeps the previous
  snapshot and is tried again an hour later.
- **Nothing is guessed.** A fact Wikidata does not have is a dash (the core ones: years, maker,
  CPU, memory) or left out; the page says where to fix it on Wikidata. Machines with no article,
  maker or year come after the others in every list.
- **The Legends** shelf is the one list kept by hand, `config/legends.yml` (QIDs).
- **The stories** are the leads of the English and Hungarian Wikipedia articles, fetched on demand
  through rubbs' `Rubbs::Common::Web::Wikipedia` (5 requests a second for all callers) and kept in
  a `Rubbs::Common::Storage::Cache`, shown with "Text from Wikipedia, CC BY-SA 4.0" and the address.
- **The photos** are the files Wikidata names for a machine (P18, about 1,700 machines) on
  [Wikimedia Commons](https://commons.wikimedia.org), shown only under a free licence (public
  domain, CC0, CC BY, CC BY-SA, by Commons' `LicenseShortName`), always with the author and the
  licence under the picture. The licence and author come from the Action API's `extmetadata`, the
  picture from a 250-pixel thumbnail. ImageMagick (`magick`, in the image) floods a plain backdrop
  black from the corners, trims it and fits the photo into 72×44 pixels for the modern face (upper
  half blocks in two xterm-256 colours a cell) and 38×40 for the C64 (twice as high, the colours
  stronger, then each cell a full block, an upper or a lower half in the nearest of the sixteen
  colours). A drawn picture, a refused licence or a missing file is kept as one JSON a machine in
  `data/pictures/`, so Commons is asked once a machine. A character copy of a CC BY-SA photo is
  under CC BY-SA too.
- **The machine of the week** is one of the machines with an English article, a year and a maker,
  picked by the ISO week (SHA-256 of `2026-W46`), the same for everyone all week (F5, `E` on the
  C64). The board writes it hourly, when the week turns, to `data/herald.json` for the Daily Herald
  of TTG Gate BBS (the Today tab).
- **The marks** ("I had one", "I grew up on it") are the callers', under their account of the
  network; the machines most callers grew up on are a shelf of their own.
- **The memories** are the callers' too: pending until an admin approves them (`bin/memories`).
  A caller may send three an hour, one every 30 seconds, and the board takes at most 30 an hour,
  counted by address (`Rubbs::Common::Line::RateLimit.caller_key`).
- **The wall and feedback** come from the network (ttg-common `TTG::Wall`, `TTG::Feedback`).

Everything from Wikidata, Wikipedia and the callers is cleaned of control characters
(`Rubbs::Common::Text.clean`) before it reaches a screen.

## Badges

`badges.rb`: **Curator** (machine pages opened: 10, 50, 200), **Collector** (machines marked: 1, 5,
20), **Nostalgic** (memories written: 1, 5).

## Running

The board is `boards/siliconia` of [TTG BBS](https://git.teletypegames.org/bbs/ttg-bbs) and runs
with the other boards in one container. From the repository root:

```bash
docker compose up --build                                       # every board, this one on 2338
bin/board siliconia                                             # only this one, on 2338 (boards.yml)
cd boards/siliconia && BBS_PORT=2338 bundle exec ruby bbs.rb    # or on its own
```

Then `telnet localhost 2338`. Every environment variable is in `env-example` with its default:

| Variable | Default | |
|---|---|---|
| `SILICONIA_BBS_CATALOG_SEED` | `config/catalog.json.gz` | the snapshot shipped with the board |
| `SILICONIA_BBS_CATALOG` | `data/catalog.json.gz` | the snapshot a refresh writes |
| `SILICONIA_BBS_CATALOG_TTL` | `604800` | seconds before Wikidata is read again; `0` never |
| `SILICONIA_BBS_LEGENDS` | `config/legends.yml` | the Legends shelf |
| `SILICONIA_BBS_WIKIPEDIA_CACHE` | `200` | Wikipedia leads kept in memory |
| `SILICONIA_BBS_DB` | `data/siliconia.sqlite3` | the marks, memories and views |
| `SILICONIA_BBS_PICTURES` | `data/pictures` | the photos drawn, one JSON a machine |
| `SILICONIA_BBS_HERALD` | `data/herald.json` | the machine of the week, for the gate's Daily Herald |
| `TTG_CENTRAL_URL` | `http://ttg-gate-bbs:8090` | the network's Central (TTG Gate BBS) |
| `RUBBS_AUTH_SECRET` | — | the secret every board of the network shares, in `.env` on the server |

`data/` is a volume (`/srv/stacks/ttg-bbs/boards/siliconia/data` on the server).

## Tests

```bash
BOARDS=siliconia bundle exec rake            # tests and bbs:check, from the repository root
BOARDS=siliconia bundle exec rake rubocop
```

Minitest, no network: the Wikidata import (stubbed SPARQL answers), the catalog's search, shelves,
family line, views and refresh, the machine records and facts, the marks and the memories, and both
faces on a fake line.

## Admin

```bash
docker exec -w /app/boards/siliconia ttg-bbs bin/memories list           # the pending memories
docker exec -w /app/boards/siliconia ttg-bbs bin/memories approved       # the approved ones
docker exec -w /app/boards/siliconia ttg-bbs bin/memories approve ID     # shown from now on
docker exec -w /app/boards/siliconia ttg-bbs bin/memories reject ID      # never shown
bin/refresh-catalog [path]          # a new seed from Wikidata (in boards/siliconia of a dev checkout)
```

## Project structure

```
bbs.rb                      entry point: Rubbs.board
badges.rb                   Curator, Collector, Nostalgic
bin/memories                the admins' tool for the memories
bin/refresh-catalog         writes the seed catalog from Wikidata
config/catalog.json.gz      the seed catalog (Wikidata, CC0)
config/legends.yml          the Legends shelf
lib/domain.rb               requires the domain in dependency order
lib/domain/
  migrations.rb             marks, memories, views
  model/machine_model.rb    a machine: QID, names, kind, years, articles, the lists
  model/mark_model.rb       the marks table
  model/memory_model.rb     the memories table
  model/view_model.rb       the views table (most viewed)
  model/summary_model.rb    a Wikipedia lead
  model/picture_model.rb    a photo: its credit and its pixels for each face
  repository/wikidata_repository.rb   the SPARQL queries (Rubbs::Common::Web::Wikidata)
  repository/wikipedia_repository.rb  English and Hungarian leads, cached
  repository/legend_repository.rb     config/legends.yml
  repository/commons_repository.rb    a Commons file's licence, author, thumbnail
  repository/pixel_repository.rb      ImageMagick: a photo into small pixels
  service/catalog_service.rb          search, shelves, family, same CPU, views, the refresh
  service/about_service.rb            a machine's Wikipedia lead
  service/collection_service.rb       the callers' marks
  service/memory_service.rb           memories: submit, limits, approve, reject
  service/picture_service.rb          the photos: free licences only, kept on disk
  service/herald_service.rb           the machine of the week for the Daily Herald
  siliconia_bbs.rb          the composition root (SiliconiaBBS, a Rubbs::Common::Board::Domain)
lib/ui/
  logo.rb                   the board's word in rubbs' block font
  wording.rb                a machine's facts and the messages, both faces
  picture.rb                a photo in characters: half blocks, xterm-256 and C64 colours
  modern.rb                 UI::Modern::APP: commands, menus, help, desktop
  modern/helpers.rb         the shelves, a machine's page, stories, family, marks, compare
  modern/windows.rb         one Rubbs::Modern::Part per window
  petscii.rb                UI::Petscii: the C64 face (a Rubbs::Petscii::Face)
  petscii/photo.rb          the photo on a C64 screen of its own
test/                       minitest tests of the domain and both faces
```

## Licence

MIT, see the repository's `LICENSE`. The catalog data is Wikidata's (CC0); the Wikipedia text
shown on the board is under CC BY-SA 4.0; each photo is under its own licence, named under it.
