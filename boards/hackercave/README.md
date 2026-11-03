# HackerCave BBS

The hacker's reading room of Teletype Games on a telnet line: every RFC, the
documents the Internet is made of, from RFC 1 of 1969 to the newest, for your
terminal or Commodore 64. A board of the Teletype Games BBS network, powered by
[rubbs](https://git.teletypegames.org/engines/rubbs).

It has two faces on one port, like every board of the network:

- a **modern** one for ANSI terminals: a desktop under a menubar, the shelves
  and their RFCs in two-pane windows with an RFC's record on the right (its
  authors, date, status and series, a red line when a newer RFC replaced it,
  the RFCs it obsoletes or updates, the abstract), a search box, an RFC's
  links as a list of their own, and a reader window that shows the RFC **as
  it was published**: its 72-column lines unchanged, the running head and
  foot of each page dim, the headings bright, and a line that says where you
  are, "RFC 793 · page 3/91 · line 140/5247";
- a **Commodore 64** one in PETSCII, 40×25: a cursor menu, the shelves and
  their RFCs as numbered lists, an RFC's record on a page with read, links
  and QR code under it, and a reader with the RFC **reflowed to 38 columns**
  (see below), in pages that wait for RETURN.

Both faces show an RFC's page at the RFC Editor,
`https://www.rfc-editor.org/rfc/rfc<N>`, as a QR code (rubbs' `BBS::QR`).

### The library

- **Classics**, **Telnet** and **April 1st**: the board's own shelves
  (`config/shelves.yml`), each RFC with a note. Telnet is the protocol this
  board talks; the notes say which options rubbs speaks (ECHO, SGA, NAWS,
  BINARY for XMODEM/ZMODEM, NEW-ENVIRON for the TTG Gate). The shelves stand
  even before the index is imported.
- **STD**, **BCP** and **FYI**: the series of the RFC Editor, each RFC with the
  number it stands for ("STD 7").
- **By status** (Internet Standard, Proposed Standard, Best Current Practice,
  Informational, Experimental, Historic, …), the newest first, and **by
  decade**, by number; at most 500 each, the rest is a search away.
- **Newest**: the 30 RFCs of the highest numbers.
- **Search**: a number (`854`, `rfc 2119`), a series (`std 7`, `bcp 14`), or
  words of the title, the authors, the keywords and the abstract, as word
  prefixes (`telnet window`), best matches first. `status:standard`
  (`proposed`, `draft`, `bcp`, `info`, `experimental`, `historic`) and
  `year:1983` narrow it. A number that was never issued says so.
- **Most read**: the RFCs opened most often on this board (the `reads` table
  of `data/hackercave.sqlite3`).

### The index

The RFC Editor's index, `https://www.rfc-editor.org/rfc-index.xml` (about
14 MB), is streamed into `data/` (`BBS::HTTP.get(url, to: file)`) and read as
a stream too (REXML's SAX2 parser, `IndexParser`), so it never sits in memory
as a tree. It goes into SQLite (`data/index.sqlite3`, about 11 MB): the RFCs
and the numbers never issued, how they are related (obsoletes, obsoleted by,
updates, updated by, see also), the STD/BCP/FYI series, and an FTS5 index of
the titles, authors, keywords and abstracts (an indexed `LIKE` where the
SQLite has no FTS5). The import runs in a background thread (rubbs'
`BBS.background`) at start when there is no index or it is older than
`HACKERCAVE_BBS_INDEX_TTL` days (one), and the thread looks again every hour;
a failed import is logged and tried again after five minutes, then less and
less often. It builds a new database next to the old one and swaps it in, so
callers keep reading meanwhile. It takes about 7 seconds.

### The texts

An RFC is fetched when someone first opens it,
`https://www.rfc-editor.org/rfc/rfc<N>.txt`, through `BBS::HTTP` (a 60-second
deadline, a 4 MB cap, redirects to public addresses only) with a User-Agent
that names the board, and kept as it came in `data/rfc/rfc<N>.txt`. That is
the layout of the RFC Editor's rsync module `rfcs-text-only`, so a mirror of
it can fill the folder. An RFC never changes: nothing there expires. Callers
opening the same RFC wait for one fetch, and at most two are fetched at once.
An opened RFC stays parsed in memory for 15 minutes (`BBS::Cache`, 24 of them).

**Modern:** the lines as published, form feeds, tabs and control characters
taken out. **Commodore 64:** `ReflowService` makes each paragraph fit 38
columns: prose is joined and wrapped again (a list item keeps a hanging
indent), a figure, table or address keeps its lines (a line too long breaks
at the gaps between its columns, then between words), a box drawing wider
than the screen comes in panels ("(columns 39-72)"), dot leaders get short,
a one-line paragraph at the margin is a heading, and the running head and
foot of each page are left out, a paragraph broken by a page joined again.
Accented letters and the characters the C64 lacks become ASCII.

The RFCs are the work of the IETF and their authors; copyright the IETF Trust
and the persons identified as authors. Each record credits "RFC N, IETF" and
links to the RFC Editor.

## Running

**Docker Compose:**

```bash
docker compose up --build
```

**Directly (Ruby 3.3):**

```bash
bundle install
BBS_PORT=2334 bundle exec ruby bbs.rb
```

Then `telnet localhost 2334`. Every environment variable is in `env-example`
with its default. The board has no secrets.

| Variable | Default | |
|---|---|---|
| `HACKERCAVE_BBS_SITE` | `https://www.rfc-editor.org` | where the index and the texts come from |
| `HACKERCAVE_BBS_INDEX_TTL` | `1` | days before the index is imported again |
| `HACKERCAVE_BBS_SHELVES` | `config/shelves.yml` | the board's own shelves |
| `HACKERCAVE_BBS_DB` | `data/hackercave.sqlite3` | the board's data: the reads |
| `HACKERCAVE_BBS_INDEX_DB` | `data/index.sqlite3` | the index in SQLite (a cache) |
| `HACKERCAVE_BBS_INDEX_FILE` | `data/rfc-index.xml` | where the download waits for the import |
| `HACKERCAVE_BBS_TEXTS` | `data/rfc` | the texts of the RFCs, as published |

`data/` is a volume. Every log line starts with the log tag `hackercave-bbs:`
(rubbs' `BBS.log`): `index refresh`, `index`, `rfc-editor`, `texts`, `shelves`.

## Tests

```bash
bundle exec bin/test            # all of them (minitest, no network)
bundle exec bin/test reflow     # the files whose name has the word
bundle exec rubocop
```

The tests cover the domain: the index import (a small `rfc-index.xml` in
`test/fixtures`), its search, relations, series and shelves, a failed import
that keeps the old index, the library service (number, series and word
searches, the refresh, the most read), parsing a text into pages, the reflow
for 38 columns, and the reading service (one fetch per RFC, kept on the
disk, counted once a call). CI runs both before a deploy.

## Project structure

```
bbs.rb                      entry point: BBS.configure + BBS::Terminal.flow
config/shelves.yml          the board's own shelves: Classics, Telnet, April 1st
lib/domain.rb               requires the domain in dependency order
lib/domain/
  model/rfc_model.rb        an RFC of the index: title, authors, date, status
  model/entry_model.rb      an RFC on a list, with a note (remark, series, relation, reads)
  model/shelf_model.rb      a shelf: own, series, status, decade, newest
  model/document_model.rb   an RFC's text in lines, and where its pages start
  repository/index_parser.rb          rfc-index.xml read as a stream
  repository/index_builder.rb         a new index database from rfc-index.xml
  repository/index_repository.rb      the index in SQLite: search, relations, series, shelves, swap
  repository/rfc_editor_repository.rb the RFC Editor over BBS::HTTP: the index, a text
  repository/text_repository.rb       data/rfc: the texts as published
  repository/shelves_repository.rb    config/shelves.yml
  repository/read_repository.rb       the reads table of data/hackercave.sqlite3 and the counts
  service/library_service.rb          shelves, search, links, most read, the index refresh
  service/reading_service.rb          opening an RFC (fetch once, parse, keep a while)
  service/reflow_service.rb           an RFC made to fit 38 columns; what each line is
  hackercave_bbs.rb         the composition root (HackerCaveBBS)
lib/ui/
  logo.rb                   HACKERCAVE in blocks (BBS::BlockFont), both faces
  modern.rb                 UI::Modern: the rubbs Application, put together from:
  modern/library.rb         the helpers: shelves, search, opening an RFC, links, QR
  modern/desktop.rb         the logo, the tagline, the statusbar
  modern/rfc_card.rb        an RFC's record beside a list
  modern/shelves_window.rb  the shelves window
  modern/rfcs_window.rb     a list of RFCs
  modern/menu.rb            the menubar, the help texts, the function keys
  modern/reader_window.rb   the reader window: the RFC as published
  petscii.rb                UI::Petscii: the C64 board
  petscii/reader.rb         the C64 reader: the RFC reflowed, in pages
  petscii/screen.rb         the 40×25 screen: rubbs' BBS::Petscii::Screen
bin/test                    runs the tests
test/                       the domain tests (minitest)
```

## License

MIT, see `LICENSE`. The RFCs are the IETF's and their authors'; see the
[IETF Trust Legal Provisions](https://trustee.ietf.org/documents/trust-legal-provisions/).
