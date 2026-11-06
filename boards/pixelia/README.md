# Pixelia BBS

The PETSCII & ANSI art gallery: classic 8-bit masterpieces and a collaborative
text-art canvas for your terminal or Commodore 64. An art board of
[Teletype Games](https://teletypegames.org), powered by
[rubbs](https://git.teletypegames.org/engines/rubbs).

It has two faces on one port, like every board of the network:

- a **modern** one for ANSI terminals: a desktop with windows, the mouse, the
  gallery in 80 columns and 16 colours, the canvas in a window with a palette;
- a **Commodore 64** one in PETSCII, 40×25: cursor menus of rubbs
  (`Rubbs::Common::Screens::Selector`: CRSR and RETURN, or the key or number as before) for the
  menu and the lists, the gallery 40 columns at a time and the canvas on the
  C64's own screen.

## The gallery

The [16colo.rs](https://16colo.rs) archive of the ANSI and ASCII scene, read on
demand from its public API (`api.16colo.rs/v1`): the years, a year's packs, a
pack's files, with the artists and groups and the 16colo.rs address of each.
Nothing is mirrored into the repository and nothing is fetched ahead: a listing
when it is opened, a file when it is shown. Every request goes through rubbs'
`Rubbs::Common::Web::HTTP` (a deadline, a cap on the body, redirects to public http(s)
addresses only) and a `Rubbs::Common::Storage::Cache`, so callers opening the same listing or
piece at once wait for one request. Listings stay in memory for
`PIXELIA_BBS_API_TTL` seconds, and a dead API gives the last one it sent;
files are cached in `data/cache/` up to `PIXELIA_BBS_CACHE_MB`, the least
recently used going first. Requests carry a `User-Agent` naming the board and
teletypegames.org. Names, credits and SAUCE texts lose their control
characters (`Rubbs::Common::Text.clean`) before they reach a screen.

Only text art is listed: `.ans .asc .diz .nfo .txt .ice`, and any file whose
SAUCE record (as the API reports it) says it is ASCII, ANSI or ANSiMation
character art, since packs give their ANSIs the group's own extension (`.RAT`,
`.CIA` …). Images, executables and binary text are left out.

A piece is rendered by the board itself (`AnsiRenderService`): the SAUCE record
(title, author, group, width, iCE colours), CP437 to Unicode, the ANSI.SYS
escape sequences (SGR, cursor moves, save and restore, ED and EL) and the line
wrap at the SAUCE width or 80, into a grid of cells. It stops at the `\x1A`
end-of-file mark, skips what it does not understand, and cuts a huge file at
`PIXELIA_BBS_MAX_FILE_KB` and `PIXELIA_BBS_MAX_ROWS`.

- **Modern:** the piece on the whole screen in the 16 ANSI colours, iCE
  backgrounds as SGR 100–107; ↑↓ PgUp PgDn Home End scroll, ← → pan when the
  window is narrower than the piece.
- **C64:** pages of 22 rows, 40 columns at a time (R shows the next 40). A C64
  cell has one colour on the black screen, ink on black or black on ink
  (reverse), so a two-colour cell keeps the colour that matters: a space on a
  background is a reversed space, a half block keeps the brighter half, text
  on a background is reversed. CGA colours go to the nearest C64 ones, the
  CP437 drawing characters the C64 lacks to their single-line cousins.

## The canvas

One shared 40×25 picture, the size of the C64's screen, so both faces show it
cell for cell. A cell is a character and the sixteen C64 colours, with at most
one colour that is not black: ink on black, or black on ink (reverse), which is
what a C64 can show. The characters are the ones both a Unicode terminal and a
C64 (through rubbs' PETSCII translation) show in one cell (`GlyphModel`):
letters, digits and most signs, `─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼`, `█ ▀ ▄ ▌ ▐`, `▒`,
`▁ ▔`, `✓ £ ← ↑`. Look-alikes (`░ ▓ ═ ║ _ | ^` …) become the C64's glyph; the
double quote, the backslash, the backtick, the braces and the tilde are refused.

Everybody sees everybody's paint: the modern face draws the canvas on every
tick, the C64 face sends only the cells that changed, after every key and
every 3 seconds. A caller paints at most `PIXELIA_BBS_PAINT_RATE` cells a second.
The canvas is written to `data/canvas.json` at most every 2 seconds, through a
temporary file of its own and a rename, by a writer thread (rubbs'
`Rubbs.background`, `canvas writer`) that also answers the admin's clear.

- **Modern:** arrows move, typing paints, Enter paints the brush, Backspace and
  Delete rub out, F7/F8 ink, F9 or Ctrl-R reverse, Insert or Ctrl-G glyph mode,
  Ctrl-S save to the Exhibition, Ctrl-Z undo. The mouse places the cursor, paints by
  dragging or with a right click, and picks inks and brushes in the panel.
- **C64:** CRSR moves, typing paints, DEL rubs out, F3/F4 ink, F5 reverse, F6
  glyph mode; RETURN (or RUN/STOP, ←) opens the command line on the status row
  (ink, reverse, glyphs, save, help, quit). F1 and F7 stay free, UltimateTerm
  keeps them. A C64's own graphics keys do not reach the board, so in **glyph
  mode** the letter keys paint the graphics, laid out like the shapes on the
  keyboard (`q w e` / `a s d` / `z x c` are the corners, tees and cross of a box,
  `g` █, `t` ▀, `b` ▄, `y` ▌, `h` ▐, `u` ▒ …). The screen shows 24 canvas rows
  and a status line, and scrolls by one when the cursor goes to the last row.

## The wall and feedback

The wall where callers talk about the art, and a word to the sysops, come from the network
(ttg-common `TTG::Wall` and `TTG::Feedback`, kept on TTG Gate BBS), in the words of
`lib/content/wall.yml`: the Exhibition menu on a modern terminal, `W` and `F` on a C64.

## The Exhibition

(It was called *the Wall* before the network got its own wall.) The canvas saved under a title
(32 characters) and the caller's name — their account of the network: a guest paints, but logs in
(the profile) to hang a work — newest first,
one JSON file each in `data/works/`. The board keeps the works it has read in
memory and lists the folder only when it changed, reading just the files it
does not know, so a save writes one file and reads none, and a work the admin
script removes is gone at the next look. A broken file is skipped with one
warning. A caller (counted by address, `Rubbs::Common::Line::RateLimit.caller_key`, so calling
again does not help) saves at most once in `PIXELIA_BBS_EXHIBITION_COOLDOWN`
seconds, and the board takes at most `PIXELIA_BBS_EXHIBITION_PER_HOUR` works an
hour. Both limits are looked at together and a save counts in both only once
its file is written, so a refused or failed save costs no turn.

## Running

**Docker Compose:**

```bash
docker compose up --build
```

**Directly (Ruby 3.x):**

```bash
bundle install
BBS_PORT=2332 bundle exec ruby bbs.rb
```

Then `telnet localhost 2332`. Every environment variable is in `env-example`
with its default. The board has no secrets.

| Variable | Default | |
|---|---|---|
| `PIXELIA_BBS_DATA` | `data` | the canvas, the Exhibition, the archive and the cache |
| `PIXELIA_BBS_API_URL` | `https://api.16colo.rs` | the 16colo.rs API |
| `PIXELIA_BBS_SITE_URL` | `https://16colo.rs` | where the raw files are |
| `PIXELIA_BBS_API_TTL` | `3600` | seconds a listing stays in memory |
| `PIXELIA_BBS_MAX_FILE_KB` | `512` | the largest art file fetched |
| `PIXELIA_BBS_CACHE_MB` | `100` | the disk cache of art files |
| `PIXELIA_BBS_MAX_ROWS` | `1000` | a piece is cut after this many rows |
| `PIXELIA_BBS_PAINT_RATE` | `20` | cells a second one caller may paint |
| `PIXELIA_BBS_EXHIBITION_COOLDOWN` | `300` | seconds between two saves of one caller |
| `PIXELIA_BBS_EXHIBITION_PER_HOUR` | `30` | works the whole board takes an hour |

`data/` is a volume.

## Administration

```bash
docker exec pixelia-bbs bin/works list          # id, date, handle, title, newest first
docker exec pixelia-bbs bin/works show ID       # a work's characters
docker exec pixelia-bbs bin/works remove ID     # moderation
docker exec pixelia-bbs bin/canvas show         # the canvas' characters
docker exec pixelia-bbs bin/canvas clear        # archive into data/archive/, then blank it
```

The running board holds the canvas in memory, so `bin/canvas clear` leaves a
flag file (`data/canvas.clear`) that the board answers within a few seconds;
when no board answers, the script clears the file itself. An archive is
`data/archive/canvas-<date>-<time>-<4 hex>.json`, written whole or not at all.

## Logs

Every line on stderr starts with the log tag `pixelia-bbs:` (rubbs' `Rubbs.log`):
`16colors`, `canvas`, `canvas writer`, `art cache`, `exhibition`. The 16colo.rs
repository lets a failure go up (`Rubbs::Common::Web::HTTP::Error`, `Rubbs::Common::Web::HTTP::TooLarge` for a
file over `PIXELIA_BBS_MAX_FILE_KB`); the gallery service logs it once and the faces
say why the piece does not show.

## Tests

```bash
bundle exec rake test            # all of them
bundle exec rake test exhibition       # the files whose name has the word
```

Minitest, in `test/domain/`: the Exhibition's rules and limits, the works folder,
the canvas file and its archive, the art cache, the 16colo.rs listings and
files (with `Rubbs::Common::Web::HTTP` stubbed: no network), the SAUCE record and the ANSI
renderer. CI runs them with RuboCop before a deploy.

## Project structure

```
bbs.rb                      entry point: Rubbs.board (the title, the domain, both faces)
bin/works, bin/canvas       admin scripts, run with docker exec
rake test                    the tests (test/domain/*_test.rb)
lib/domain.rb               requires the domain in dependency order
lib/domain/
  model/color_model.rb      the sixteen C64 colours (ANSI and xterm-256 too)
  model/glyph_model.rb      the characters a canvas cell may hold
  model/canvas_model.rb     a 40×25 picture, frozen; its JSON
  model/work_model.rb       a picture on the Exhibition
  model/sauce_model.rb      the SAUCE record of an art file
  model/art_model.rb        a rendered piece: rows of cells, packed
  model/year_model.rb, pack_model.rb, art_file_model.rb   the 16colo.rs listings
  repository/sixteen_colors_repository.rb   the API and the raw files, listings cached
  repository/art_cache_repository.rb        data/cache/, least recently used out
  repository/canvas_repository.rb           the live canvas and data/canvas.json
  repository/work_repository.rb             data/works/
  service/ansi_render_service.rb            ANSI/ASCII bytes → ArtModel
  service/gallery_service.rb                years, packs, text-art files, a piece
  service/canvas_service.rb                 painting rules, rate limit, undo, who is here
  service/exhibition_service.rb                   saving to the Exhibition, its limits
  pixelia_bbs.rb            the board's domain (PixeliaBBS): settings and services
lib/ui/
  logo.rb                   PIXELIA in blocks (Rubbs::Common::Text::BlockFont), a colour a letter, both faces
  glyph_keys.rb             glyph mode's keyboard, both faces
  wording.rb              what a caller is told about a save, both faces
  modern.rb                 UI::Modern::APP: commands, menus, help, statusbar and desktop
  modern/helpers.rb         what the caller does: opening windows, a piece, the canvas, saving
  modern/years_window.rb, packs_window.rb, files_window.rb, exhibition_window.rb   one window each
  modern/save_window.rb     the form that saves the canvas to the Exhibition
  modern/canvas_widget.rb   the canvas's keys and mouse, and its window
  modern/canvas_panel.rb    drawing the canvas and its panel
  modern/viewer.rb          a piece or a work on the whole screen
  modern/art_lines.rb       rows of cells as ANSI lines
  petscii.rb                UI::Petscii: the C64 face, its masthead and main menu
  petscii/pen.rb            cells in C64 colours and reverse; ANSI cells to C64 ones
  petscii/canvas_view.rb    the canvas on a C64 screen, sending only what changed
  petscii/canvas.rb         painting on a C64
  petscii/gallery.rb        the 16colo.rs gallery on a C64
  petscii/exhibition.rb           the Exhibition on a C64
```

## License

MIT, see `LICENSE`. The art in the gallery belongs to its artists and is shown
from [16colo.rs](https://16colo.rs).
