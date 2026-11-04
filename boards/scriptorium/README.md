# Scriptorium BBS

The classic literature vault of Teletype Games on a telnet line: thousands of
books from [Project Gutenberg](https://www.gutenberg.org), cut into pageable
chapters for your terminal or Commodore 64.

It has two faces on one port, like every board of the network:

- a **modern** one for ANSI terminals: a desktop under a menubar, the shelves
  and their books in two-pane windows with a book's record on the right, a
  search box, a book's chapters with the start of the one picked, and a
  reader window that wraps the chapter to its width (PgUp/PgDn, Home/End,
  ←/→ for the previous and the next chapter, F5 for the whole screen) and says
  where you are: "Chapter 3/42 · page 2/9";
- a **Commodore 64** one in PETSCII, 40×25: a one-key menu, numbered lists, a
  book's record on a page, its chapters as a numbered list, and a reader of
  38-column pages that wait for RETURN, `n` / `p` for the next and the previous
  chapter, `b` back a page, `q` back to the list. Typography and accented
  letters become the ASCII the C64 has.

Both faces show a book's Project Gutenberg page,
`https://www.gutenberg.org/ebooks/<number>`, as a QR code (rubbs'
`BBS::QR`), so a phone or an e-reader takes the whole book (EPUB, Kindle)
from there: the **QR code** button of the books and the chapters windows on
the modern face (half blocks, in a window as big as the screen allows), and
`c` (qr code) under a book's record on the C64 (quadrant blocks, in the middle
of the screen).

### The library

- **Classics** — the board's own shelf of well-known books
  (`config/classics.yml`). It stands even before the catalog is imported.
- **Bookshelves** — the bookshelves and categories of Project Gutenberg, from
  the `Bookshelves` column of its catalog. A shelf lists its first 200 books by
  ebook number.
- **Search** — every word of the title or the author, as a word prefix
  (`dick tale`), accents ignored. `lang:fr` (or the Language field of the
  modern face) keeps to one language.
- **Most read** — the books opened most often on this board (the `reads`
  table of `data/scriptorium.sqlite3`).

### The catalog

Project Gutenberg's own catalog, `pg_catalog.csv.gz` (about 5.6 MB), is
streamed into `data/` (`BBS::HTTP.get(url, to: file)`: the download never sits
in memory) and its `Text` rows imported into SQLite
(`data/catalog.sqlite3`, about 33 MB) with an FTS5 index of titles and authors
(an indexed `LIKE` where the SQLite has no FTS5). The import runs in a
background thread (rubbs' `BBS.background`) at start when there is no catalog or it is older than
`SCRIPTORIUM_BBS_CATALOG_TTL` days, and the thread looks again every hour; a
failed import is logged and tried again after five minutes, then less and less
often, at most hourly. It builds
a new database next to the old one and swaps it in, so callers keep reading
meanwhile. Until the first import is done the Classics shelf is open and the
rest says the catalog is being prepared. No list is held in Ruby: every shelf
and search is a query.

### The texts

A book is fetched when someone first opens it:
`<mirror>/cache/epub/<N>/pg<N>.txt`, through `BBS::HTTP` (a 60-second
deadline, the size cap below, redirects to public http(s) addresses only)
with a User-Agent that names the board.
The board takes off the Project Gutenberg header and footer (`*** START OF …`,
`*** END OF …`), evens out the line ends, drops the control characters (a form
feed would clear a C64's screen), and joins the hard-wrapped lines of a
paragraph (verse, lists and tables of contents keep their lines). It cuts the
text into chapters by their headings (CHAPTER, BOOK, PART, ACT, STAVE, LETTER,
CANTO, PREFACE, a roman numeral on its own line…): a table of contents that
lists the same headings is skipped, and a heading right above another
("BOOK ONE · CHAPTER I") is joined to it. A chapter over 40 KB is read in parts,
and a book without headings in sections of about 16 KB ("Part 1/23").

The cleaned text and its chapter index are cached in `data/texts/` (at most
`SCRIPTORIUM_BBS_CACHE_MB`, the books read least recently go first). A chapter is
read from the file when it is shown: no session keeps a whole book. A text
longer than `SCRIPTORIUM_BBS_BOOK_MAX` is refused (`BBS::HTTP::TooLarge`, as soon
as the mirror's Content-Length says so). Callers opening the same
book wait for one fetch, and at most two books are fetched and cut at once
(a caller waits a minute at most for a turn); the text is cleaned in place
and cutting it keeps only offsets, so a big book is not copied over and over.

The texts are public domain in the USA. Each book's page credits it:
"eBook #N from Project Gutenberg, gutenberg.org/ebooks/N".

## Running

**Docker Compose:**

```bash
docker compose up --build
```

**Directly (Ruby 3.3):**

```bash
bundle install
BBS_PORT=2330 bundle exec ruby bbs.rb
```

Then `telnet localhost 2330`. Every environment variable is in `env-example`
with its default. The board has no secrets.

| Variable | Default | |
|---|---|---|
| `SCRIPTORIUM_BBS_MIRROR` | `https://www.gutenberg.org` | where the plain texts come from |
| `SCRIPTORIUM_BBS_CATALOG_URL` | `<mirror>/cache/epub/feeds/pg_catalog.csv.gz` | the catalog file |
| `SCRIPTORIUM_BBS_CATALOG_TTL` | `7` | days before the catalog is imported again |
| `SCRIPTORIUM_BBS_CLASSICS` | `config/classics.yml` | the Classics shelf |
| `SCRIPTORIUM_BBS_DB` | `data/scriptorium.sqlite3` | the board's data: the reads |
| `SCRIPTORIUM_BBS_CATALOG_DB` | `data/catalog.sqlite3` | the catalog in SQLite (a cache) |
| `SCRIPTORIUM_BBS_CATALOG_FILE` | `data/pg_catalog.csv.gz` | where the download waits for the import |
| `SCRIPTORIUM_BBS_TEXTS` | `data/texts` | the cleaned texts and chapter indexes |
| `SCRIPTORIUM_BBS_CACHE_MB` | `300` | the most the text cache takes |
| `SCRIPTORIUM_BBS_BOOK_MAX` | `8388608` | the longest plain text fetched, in bytes |
`data/` is a volume. A `data/reads.jsonl` left by an older board (one JSON line
a read) is imported into the `reads` table on the first start, one
transaction, an unreadable line skipped, and renamed `reads.jsonl.imported`;
the log says `scriptorium-bbs: reads: imported N reads from reads.jsonl (M skipped)`.

Every log line starts with the log tag `scriptorium-bbs:` (rubbs' `BBS.log`):
`catalog refresh`, `catalog`, `gutenberg`, `text cache`, `reads`. The Gutenberg
repository lets a failure go up; the services (and the refresh thread) log it
once.

## Tests

```bash
bundle exec rake test            # all of them (minitest, no network)
bundle exec rake test reading    # the files whose name has the word
bundle exec rubocop
```

The tests cover the domain: the reads and their legacy import, cleaning and
cutting a text, the reading service (one fetch per book, a few at once), the
text cache, the catalog import and search, and the Gutenberg repository
against a stubbed `BBS::HTTP`. CI runs both before a deploy.

## Project structure

```
bbs.rb                      entry point: BBS.configure + BBS::Terminal.flow
config/classics.yml         the Classics shelf: ebook numbers, titles, authors
lib/domain.rb               requires the domain in dependency order
lib/domain/
  model/book_model.rb       a book of the catalog: title, authors, language, shelves
  model/shelf_model.rb      a bookshelf, or the Classics shelf
  model/chapter_model.rb    a chapter: its title and byte range in the cached text
  model/text_model.rb       a book ready to read: its chapter index
  repository/gutenberg_repository.rb    Project Gutenberg over BBS::HTTP: the catalog file, a plain text
  repository/catalog_repository.rb      the catalog in SQLite: import, search, shelves
  repository/classics_repository.rb     config/classics.yml
  repository/read_repository.rb         the reads table of data/scriptorium.sqlite3 and the counts
  repository/legacy_reads.rb            the one-time import of an older data/reads.jsonl
  repository/text_cache_repository.rb   data/texts: cleaned texts, chapter indexes, eviction
  service/chapter_service.rb            cleaning a text and cutting it into chapters
  service/library_service.rb            shelves, search, most read, the catalog refresh
  service/reading_service.rb            opening a book (fetch, cut, cache) and its chapters
  scriptorium_bbs.rb        the composition root (ScriptoriumBBS)
lib/ui/
  logo.rb                   SCRIPTORIUM in blocks (BBS::BlockFont), both faces
  modern.rb                 UI::Modern: the rubbs Application, put together from:
  modern/library.rb         the helpers: shelves, search, opening a book
  modern/desktop.rb         the logo, the tagline, the statusbar
  modern/book_card.rb       a book's record beside a list of books
  modern/shelves_window.rb  the bookshelves window
  modern/books_window.rb    a list of books
  modern/chapters_window.rb a book's chapters
  modern/menu.rb            the menubar, the help texts, the function keys
  modern/reader_window.rb   the reader window
  petscii.rb                UI::Petscii: the C64 board
  petscii/reader.rb         the C64 reader: 38-column pages
  petscii/screen.rb         the 40×25 screen: rubbs' BBS::Petscii::Screen
rake test                    runs the tests
test/                       the domain tests (minitest)
```

## License

MIT, see `LICENSE`. The books are Project Gutenberg's; see
[gutenberg.org/policy/license](https://www.gutenberg.org/policy/license.html).
