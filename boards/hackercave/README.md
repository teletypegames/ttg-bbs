# HackerCave BBS

The hacker's reading room of Teletype Games on a telnet line: every RFC, the
documents the Internet is made of, from RFC 1 of 1969 to the newest, the
Internet Experiment Notes before them, and the Jargon File, for your terminal
or Commodore 64. A board of the Teletype Games BBS network, powered by
[rubbs](https://git.teletypegames.org/engines/rubbs).

It has two faces on one port, like every board of the network:

- a **modern** one for ANSI terminals: a desktop under a menubar, the shelves
  and their RFCs in two-pane windows with an RFC's record on the right (its
  authors, date, status and series, a red line when a newer RFC replaced it,
  the RFCs it obsoletes or updates, the abstract), a search box, an RFC's
  links and its errata, and a reader window that shows the RFC **as it was
  published**: its 72-column lines unchanged, the running head and foot of
  each page dim, the headings bright, the RFCs it names coloured, a line that
  says where you are, "RFC 793 · page 3/91 · line 140/5247", and Contents
  (jump to a heading) and References (the RFCs it names);
- a **Commodore 64** one in PETSCII, 40×25: a cursor menu, the shelves and
  their RFCs as numbered lists, an RFC's record on a page with read, links,
  errata and QR code under it, and a reader with the RFC **reflowed to 38
  columns** (see below), in pages that wait for RETURN, `t` for its contents
  and `f` for the RFCs it names.

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
- **This month**: the RFCs published in the month we are in, from the first
  year on.
- **Newest**: the 30 RFCs of the highest numbers.
- **IENs**: the Internet Experiment Notes of 1977-1982 (IEN 137, "On Holy Wars
  and a Plea for Peace", named the little- and big-endians), the working papers
  of TCP/IP before the RFCs took over; 134 of the 209 are text, the rest only
  scans, which the record links to.
- **Search**: a number (`854`, `rfc 2119`), a series (`std 7`, `bcp 14`), or
  words of the title, the authors, the keywords and the abstract, as word
  prefixes (`telnet window`), best matches first. `status:standard`
  (`proposed`, `draft`, `bcp`, `info`, `experimental`, `historic`) and
  `year:1983` narrow it. A number that was never issued says so. `ien 137`
  finds an IEN.
- **Search the text** (F9, `6` on the C64): words anywhere in the text of
  every RFC and IEN, best matches first, each with the first line that has the
  first word.
- **Errata**: an RFC's record says how many errata the RFC Editor has for it
  (how many verified); Alt-E (`e`) lists them, what the RFC says and what it
  should say.
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

### The Jargon File

The Jargon File 4.4.7 (29 Dec 2003), the lexicon of hacker slang, is in the
public domain and ships with the board (`config/jargon/jarg447.txt`). At the
first start (and when the file changes) `JargonParser` reads it into
`data/jargon.sqlite3`: 2,308 entries, each with its headword, pronunciation
and paragraphs (a justified paragraph on one line, an example kept as it is),
the 17 other parts (the welcome, the introduction's chapters, Hacker Folklore,
the portrait of J. Random Hacker, the bibliography), and an FTS5 index. The
Jargon menu (`j` on the C64) has the word of the day (the same for everyone on
a day), the lexicon by letter, a search, a random entry, and the chapters; an
entry's `{links}` are coloured and listed with Alt-L (`l`). Every entry is
credited "Jargon File 4.4.7 (public domain)".

### The texts

An RFC is fetched when someone first opens it,
`https://www.rfc-editor.org/rfc/rfc<N>.txt`, through `BBS::HTTP` (a 60-second
deadline, a 4 MB cap, redirects to public addresses only) with a User-Agent
that names the board, and kept as it came in `data/rfc/rfc<N>.txt`. That is
the layout of the RFC Editor's rsync module `rfcs-text-only`. An RFC never
changes: nothing there expires. An IEN is `ien<N>.txt` beside them.

**The mirror** (`MirrorService`) fills that folder with every RFC once a day:
`rsync -rt rsync://rsync.rfc-editor.org/rfcs-text-only/` (about 540 MB, the
first time; later only what changed), fetches the IENs that are text, and
indexes every new or changed text in `data/fulltext.sqlite3`, a contentless
FTS5 table (about 135 MB: the index only, not the text again). It indexes one
text at a time and collects the garbage every 200, so the board stays under
80 MB; the first run takes a few minutes, mostly the download. A search reads
the first line with the word from the file. `HACKERCAVE_BBS_MIRROR=off` turns
it off; without it texts are fetched on the first read as before. Callers
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
| `HACKERCAVE_BBS_TEXTS` | `data/rfc` | the texts of the RFCs and IENs, as published |
| `HACKERCAVE_BBS_ERRATA_FILE` | `data/errata.json` | where the errata download waits for the import |
| `HACKERCAVE_BBS_MIRROR` | `on` | `off` turns the mirror and the text search off |
| `HACKERCAVE_BBS_MIRROR_SOURCE` | `rsync://rsync.rfc-editor.org/rfcs-text-only/` | the rsync module |
| `HACKERCAVE_BBS_MIRROR_TTL` | `1` | days between two syncs |
| `HACKERCAVE_BBS_FULLTEXT_DB` | `data/fulltext.sqlite3` | the full-text index |
| `HACKERCAVE_BBS_JARGON_DB` | `data/jargon.sqlite3` | the Jargon File, built from `config/jargon` |

`data/` is a volume. Every log line starts with the log tag `hackercave-bbs:`
(rubbs' `BBS.log`): `index refresh`, `index`, `rfc-editor`, `texts`, `shelves`,
`mirror`, `fulltext`, `jargon`.

## Tests

```bash
bundle exec bin/test            # all of them (minitest, no network)
bundle exec bin/test reflow     # the files whose name has the word
bundle exec rubocop
```

The tests cover the domain: the index import (small `rfc-index.xml`,
`errata.json`, IEN index and listing in `test/fixtures`), its search,
relations, series, shelves, IENs and errata, a failed import that keeps the
old index, an older board's index imported anew, the library service
(number, series, word and text searches, the most read), parsing a text into
pages, the reflow for 38 columns, the reading service (one fetch per RFC,
kept on the disk, counted once a call, contents and the RFCs named), the
mirror (a stubbed rsync, only what changed indexed again), and the Jargon
File (a small Latin-1 file: entries, links, sections, search, the word of the
day). CI runs both before a deploy.

## Project structure

```
bbs.rb                      entry point: BBS.configure + BBS::Terminal.flow
config/shelves.yml          the board's own shelves: Classics, Telnet, April 1st
config/jargon/jarg447.txt   the Jargon File 4.4.7 (public domain)
lib/domain.rb               requires the domain in dependency order
lib/domain/
  model/rfc_model.rb        an RFC of the index: title, authors, date, status
  model/entry_model.rb      an RFC on a list, with a note (remark, series, relation, reads)
  model/shelf_model.rb      a shelf: own, series, status, decade, newest
  model/document_model.rb   an RFC's text in lines, and where its pages start
  model/erratum_model.rb    an erratum of an RFC
  model/jargon_entry_model.rb, jargon_section_model.rb   the Jargon File's entries and parts
  repository/index_parser.rb          rfc-index.xml read as a stream
  repository/index_builder.rb         a new index database from rfc-index.xml
  repository/index_repository.rb      the index in SQLite: search, relations, series, swap
  repository/index_shelves.rb         its shelves: status, decade, month, newest, IENs
  repository/index_errata.rb          its errata
  repository/ien_index.rb             ien-index.txt: the IENs' numbers, authors, dates, titles
  repository/rfc_editor_repository.rb the RFC Editor over BBS::HTTP: the index, a text
  repository/text_repository.rb       data/rfc: the texts as published
  repository/fulltext_repository.rb   data/fulltext.sqlite3: the full-text index of the texts
  repository/jargon_parser.rb         jarg447.txt read into entries and sections
  repository/jargon_repository.rb     data/jargon.sqlite3: built from it, searched
  repository/shelves_repository.rb    config/shelves.yml
  repository/read_repository.rb       the reads table of data/hackercave.sqlite3 and the counts
  service/library_service.rb          shelves, search, links, errata, most read
  service/import_service.rb           the daily import: index, errata, IENs
  service/mirror_service.rb           the rsync mirror and the text search
  service/jargon_service.rb           the Jargon File: letters, search, word of the day
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
  modern/contents_window.rb the headings of the RFC read, to jump to
  modern/text_window.rb     a window of paragraphs: errata, a Jargon entry or chapter
  modern/jargon.rb          the Jargon menu's helpers and windows
  petscii.rb                UI::Petscii: the C64 board
  petscii/records.rb        the lists and an RFC's record: links, errata, QR code
  petscii/reader.rb         the C64 reader: the RFC reflowed, in pages, contents
  petscii/jargon_room.rb    the Jargon File on the C64
  petscii/screen.rb         the 40×25 screen: rubbs' BBS::Petscii::Screen
bin/test                    runs the tests
test/                       the domain tests (minitest)
```

## License

MIT, see `LICENSE`. The RFCs are the IETF's and their authors'; see the
[IETF Trust Legal Provisions](https://trustee.ietf.org/documents/trust-legal-provisions/).
The IENs carry no notice and are published by the RFC Editor. The Jargon File
is in the public domain.
