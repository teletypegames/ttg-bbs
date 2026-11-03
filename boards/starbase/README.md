# Starbase BBS

A Star Trek library on a telnet line: every series and film with its
episodes, the day each first aired, its directors and writers, and the
articles of Memory Alpha, the fans' wiki, read section by section. A board of
the Teletype Games BBS network, powered by
[rubbs](https://git.teletypegames.org/engines/rubbs).

It has two faces on one port, like every board of the network:

- a **modern** one for ANSI terminals: a desktop under a menubar, the series,
  a series' episodes and the episodes aired on this day in two-pane windows
  with the picked one's card on the right, the library computer (a search of
  Memory Alpha) in a dialog, and an article with its sections on the left;
- a **Commodore 64** one in PETSCII, 40×25: cursor menus of rubbs
  (`BBS::Selector`: CRSR and RETURN, or the key or number), the series, their
  seasons and episodes as numbered lists, an episode's card a page, an article
  as its contents and each section paged.

Star Trek is a trademark of Paramount. This is a fan library, not affiliated
with Paramount; the board shows no scripts, transcripts or pictures.

## Where the data comes from

- **The catalog** is [Wikidata](https://www.wikidata.org)'s, under CC0, read
  with rubbs' `BBS::Wikidata`: every item that is a Star Trek episode
  (Q61220733) with the series it is part of (P179), its season (P4908) and its
  numbers (P1545 qualifiers), the first date it aired (P577), its directors
  (P57) and screenwriters (P58); every film of the franchise (P8345 = Q1092)
  that is not an episode and has a Memory Alpha article; and the series with
  three episodes or more, with their years (P580, P582). An item's Memory Alpha
  article is its Fandom article id (P6262, `memory-alpha:…`); of several, the
  one of the episode or film itself. About 1,000 episodes and films in 15
  series. The seed ships with the image (`config/catalog.json.gz`); the board
  reads Wikidata again in the background when its copy is a week old and keeps
  the new one in `data/`.
- **The articles** are [Memory Alpha](https://memory-alpha.fandom.com)'s, under
  CC BY-NC, read on demand from its Action API with rubbs' `BBS::MediaWiki`
  (three requests a second, all callers together) and kept for half an hour
  in a `BBS::Cache`: the plain-text extract cut into its sections
  (`BBS::MediaWiki::Extract`), without the links and references. An episode
  opens the article Wikidata names, else the one of its title, else the first
  search hit for it. A typed title in another case ("data") opens its article
  too.

Every article ends with its address and licence, and both faces can show the
article's address as a QR code (rubbs' `BBS::QR`), by its page id
(`https://memory-alpha.fandom.com/?curid=…`), so it stays short.

## Using it

**Modern:** the series window opens on the desktop. Enter opens a series'
episodes, Enter on an episode its article; `Article` opens a series' own.

| Key | Action |
|---|---|
| `F2` | Series |
| `F3` | On this day: what first aired on today's date |
| `F4` | Library computer: search Memory Alpha |
| `F7` | A random article |
| `Alt-Q` | QR code of the article (in an article window) |
| `F5` / `Alt-Enter` | Full screen and back |
| `F6` / `Shift-F6` | Next / previous window |
| `Esc` | Close the window |
| `F10` | Menu |
| `Alt-X` | Log off |

**C64:** the menu: `S` series and films, `T` on this day, `L` library
computer, `R` random article, `Q` log off. A series with seasons asks for the
season first. Under an episode's card `R` reads its article; an article is its
list of sections, `C` shows its QR code.

## Running

**Docker Compose:**

```bash
docker compose up --build
```

**Directly (Ruby 3.3):**

```bash
bundle install
BBS_PORT=2333 bundle exec ruby bbs.rb
```

Then `telnet localhost 2333`. Every environment variable is in `env-example`
with its default.

| Variable | Default | |
|---|---|---|
| `STARBASE_BBS_CATALOG_SEED` | `config/catalog.json.gz` | the snapshot shipped with the image |
| `STARBASE_BBS_CATALOG` | `data/catalog.json.gz` | the snapshot a refresh writes |
| `STARBASE_BBS_CATALOG_TTL` | `604800` | seconds before Wikidata is read again |

The board keeps no other data and has no secrets.

## Tests

```bash
bundle exec rake test
```

Minitest, no network: the catalog's order, seasons and days, the series'
names and abbreviations, the Wikidata import (numbers, the earliest date, the
people, the article of the episode itself, the films), the Memory Alpha
article model, the library's look-up. CI runs them before a deploy.

## Logs

Every line on stderr starts with the log tag `starbase-bbs:` (rubbs'
`BBS.log`): `starbase-bbs: catalog: …`, `starbase-bbs: memory-alpha: …`. The
repositories let a failure go up; the services (and the refresh thread) log it
once.

## Admin

```bash
bin/refresh-catalog [path]     # a new seed from Wikidata (in a dev checkout)
```

## Project structure

```
bbs.rb                      entry point: BBS.configure + BBS::Terminal.flow
bin/refresh-catalog         writes the seed catalog from Wikidata
config/catalog.json.gz      the seed catalog (Wikidata, CC0)
lib/domain.rb               requires the domain in dependency order
lib/domain/
  model/series_model.rb     a series (or the films): title, years, article, abbreviation
  model/episode_model.rb    an episode or film: numbers, air date, people, article
  model/article_model.rb    a Memory Alpha article in sections, its short address
  model/section_model.rb    a section of an article
  model/search_result_model.rb  a search hit
  repository/wikidata_repository.rb       the SPARQL queries (BBS::Wikidata)
  repository/catalog_repository.rb        the snapshot files, the catalog in memory
  repository/memory_alpha_repository.rb   the Action API (BBS::MediaWiki), cached
  service/catalog_service.rb              series, seasons, on this day, the refresh
  service/library_service.rb              look-up, articles, an episode's article
  starbase_bbs.rb           the composition root (StarbaseBBS)
lib/ui/
  logo.rb                   STARBASE in blocks (BBS::BlockFont), both faces
  card.rb                   an episode's and a series' facts, both faces
  modern.rb                 UI::Modern: the rubbs Application and its parts
  modern/helpers.rb         the windows it opens, the library, the QR code, the desktop
  modern/menu.rb            the menubar, the status bar's hints
  modern/series_window.rb, episodes_window.rb, results_window.rb,
  modern/article_window.rb  one module per window
  petscii.rb                UI::Petscii: the masthead, the flow, goodbye
  petscii/screen.rb         the 40×25 screen: rubbs' BBS::Petscii::Screen
  petscii/library.rb        the C64 menu, the series, seasons, episodes, cards
  petscii/reader.rb         Memory Alpha on the C64: search, contents, sections, QR
test/                       minitest tests of the domain
Rakefile                    rake test
```

## Licence

MIT, see `LICENSE`. The catalog data is Wikidata's (CC0); the Memory Alpha
text shown on the board is under CC BY-NC. Star Trek is a trademark of
Paramount.
