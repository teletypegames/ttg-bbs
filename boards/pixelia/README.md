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

(It was called *the Wall* before the network got its own wall.) Works under a title (32
characters) and the caller's name — their account of the network: a guest paints, but logs in
(the profile) to hang a work — newest first, one JSON file each in `data/works/`. A work is one
of two kinds:

- a **canvas work**: the canvas as it was saved (`CanvasModel`, the canvas's own JSON under
  `canvas`);
- a **PETSCII work**: a picture of [TTG Canvas 64](https://git.teletypegames.org/tools/ttg-canvas-64),
  uploaded (`PetsciiModel`, under `petscii`): the 40×25 screen codes (reverse in bit 7) and a
  colour per cell, any of the sixteen on any background, the border and background colour and
  one of the ROM character sets, upper case / graphics or lower / upper case.

The board keeps the works it has read in memory and lists the folder only when it changed,
reading just the files it does not know, so a save writes one file and reads none, and a work
the admin script removes is gone at the next look. A broken file is skipped with one warning.
A caller (counted by address, `Rubbs::Common::Line::RateLimit.caller_key`, so calling again
does not help) hangs at most one work in `PIXELIA_BBS_EXHIBITION_COOLDOWN` seconds, and the
board takes at most `PIXELIA_BBS_EXHIBITION_PER_HOUR` works an hour; saves and uploads count
together. Both limits are looked at together and a work counts in both only once its file is
written, so a refused or failed one costs no turn.

### Upload

The Exhibition's **Upload** (the menu and the window's button on a modern terminal, `3` then
`U` on a C64) takes a `.tcv` file by **XMODEM** from a logged-in caller, from any terminal:
TTG Gate 64, UltimateTerm, CCGMS, SyncTERM. The board receives with rubbs'
`Rubbs::Common::Files::Transfer.receive` (checksum, CRC-16 and 1K blocks, as the terminal
sends), at most `ExhibitionService::MAX_UPLOAD` (5 KiB) bytes, a minute to start; Esc or
RUN/STOP gives up. Nothing is written before the file is judged (`ExhibitionService#accept`,
`TcvModel`), the way `FORMAT.md` of TTG Canvas 64 asks: a load address in front is skipped,
the header checked, exactly 2016 (or 4064) bytes taken and XMODEM's padding after them
ignored, every colour masked to its low nibble, a newer version refused. Then:

- a **multicolour** picture or one with a **custom character set** is refused as game
  graphics, which a terminal cannot show;
- a broken file is refused with the reader's reason (`not a TTG Canvas 64 picture`,
  `the picture is cut short (2000 of 2016 bytes)` …);
- an empty one (nothing but the background) is refused too.

A picture taken asks for its title, and the work hangs at once. Every upload is noted for the
sysops (`UploadNoteService`): a feedback of the board's own kind `upload` on the network's
feedback box (ttg-common `TTG::Feedback`, on TTG Gate BBS), sent as the uploader. The Central
posts its Discord line (`TTG_GATE_BBS_FEEDBACK_WEBHOOK`: board, kind, who, never the text) and
the sysops' desk keeps the title, the work's id and the `bin/works remove` line. A note that
does not go (the Central away, the uploader's feedback limit) is logged and costs the work
nothing. The board needs no webhook of its own.

### A PETSCII work on the two faces

- **C64:** exactly as painted, on the C64's own screen in the picture's character set: every
  screen code, colour and reverse cell (`UI::Petscii::WorkScreen`, a `Rubbs::Petscii::Canvas`);
  any key goes back. Two things a telnet line cannot carry: the **border and background
  colour** (no terminal has a code for `$D020`/`$D021`, so the screen stays the terminal's
  black) and the **last cell** of the screen (printing there scrolls a C64). On a black
  background, the usual one, the picture is exact. On another background a cell is drawn the
  closest way a black screen allows: a space, or anything in the background colour, is a
  reversed space in it; a character in black ink is that character reversed in the background
  colour (exact); a character in another ink keeps the background around a black character; a
  reversed character keeps its ink around a black one.
- **Modern:** in the xterm-256 colours of the C64 palette (`ColorModel`), so every ink and
  background colour is shown as it is, a reversed cell with ink and background swapped, and on
  the whole screen in a frame of its border colour (two columns, one row). The shapes are
  approximated: each screen code is the Unicode character it looks like in its set
  (`PetsciiGlyphModel`): rubbs' tables (`Rubbs::Petscii::Canvas.look`, `Rubbs::Petscii::Glyphs`)
  for the letters, signs, lines, blocks, suits and diagonals, and for the graphics they leave out
  the nearest character every terminal font has (the eighth lines at other heights as `─ │`, the
  quarter and three-eighth bars as `▎ ▍ ▕ ▂ ▃`, the corner pieces as box corners, the half
  shades and the lower set's patterns as `▒`). The lower / upper case set shows its letters in
  both cases. The Exhibition window's preview is the picture without its frame.

## Running

The board is `boards/pixelia` of [TTG BBS](https://git.teletypegames.org/bbs/ttg-bbs) and runs
with the other boards in one container. From the repository root:

**Docker Compose** (every board, this one on 2332):

```bash
docker compose up --build
```

**Directly (Ruby 3.x):**

```bash
bundle install
bin/board pixelia                                            # on 2332 (boards.yml)
cd boards/pixelia && BBS_PORT=2332 bundle exec ruby bbs.rb   # or on its own
```

Then `telnet localhost 2332`. Every environment variable is in `env-example`
with its default; in Docker the root `compose.yaml` sets the ones that differ (a secret from
the stack's `.env`). The board has no secrets.

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
| `PIXELIA_BBS_EXHIBITION_COOLDOWN` | `300` | seconds between two works (saves or uploads) of one caller |
| `PIXELIA_BBS_EXHIBITION_PER_HOUR` | `30` | works (saves and uploads) the whole board takes an hour |

`data/` is a volume (`/srv/stacks/ttg-bbs/boards/pixelia/data` on the server).

## Administration

```bash
docker exec -w /app/boards/pixelia ttg-bbs bin/works list          # id, date, handle, title, newest first
docker exec -w /app/boards/pixelia ttg-bbs bin/works show ID       # a work's characters (a PETSCII work's look-alikes)
docker exec -w /app/boards/pixelia ttg-bbs bin/works remove ID     # moderation
docker exec -w /app/boards/pixelia ttg-bbs bin/canvas show         # the canvas' characters
docker exec -w /app/boards/pixelia ttg-bbs bin/canvas clear        # archive into data/archive/, then blank it
```

The running board holds the canvas in memory, so `bin/canvas clear` leaves a
flag file (`data/canvas.clear`) that the board answers within a few seconds;
when no board answers, the script clears the file itself. An archive is
`data/archive/canvas-<date>-<time>-<4 hex>.json`, written whole or not at all.

## Logs

Every line on stderr starts with the log tag `pixelia-bbs:` (rubbs' `Rubbs.log`):
`16colors`, `canvas`, `canvas writer`, `art cache`, `exhibition` (an upload's note that did not
go: `upload note not sent`), `transfer` (an upload: `received`, or how it failed). The 16colo.rs
repository lets a failure go up (`Rubbs::Common::Web::HTTP::Error`, `Rubbs::Common::Web::HTTP::TooLarge` for a
file over `PIXELIA_BBS_MAX_FILE_KB`); the gallery service logs it once and the faces
say why the piece does not show. In the container they are in `docker logs ttg-bbs`, with
`"board":"pixelia-bbs"`.

## Tests

In `boards/pixelia`:

```bash
bundle exec rake test            # all of them
bundle exec rake test exhibition       # the files whose name has the word
```

Minitest, in `test/domain/`: the Exhibition's rules and limits (uploads among them), the `.tcv`
reader and the PETSCII work (with the samples of TTG Canvas 64 in `test/fixtures/`), the
upload note, the works folder, the canvas file and its archive, the art cache, the 16colo.rs
listings and files (with `Rubbs::Common::Web::HTTP` stubbed: no network), the SAUCE record and
the ANSI renderer; in `test/ui/`: both faces, a C64 upload (the XMODEM transfer stubbed; rubbs
tests the transfer itself) and its refusals, a PETSCII work on both faces. CI runs them with
RuboCop before a deploy.

## Project structure

```
bbs.rb                      entry point: Rubbs.board (the title, the domain, both faces)
bin/works, bin/canvas       admin scripts, run with docker exec
rake test                   the tests (test/domain, test/ui; samples in test/fixtures)
lib/domain.rb               requires the domain in dependency order
lib/domain/
  model/color_model.rb      the sixteen C64 colours (ANSI and xterm-256 too)
  model/glyph_model.rb      the characters a canvas cell may hold
  model/canvas_model.rb     a 40×25 picture, frozen; its JSON
  model/tcv_model.rb        a TTG Canvas 64 file (.tcv), read the safe way
  model/petscii_model.rb    a PETSCII work: screen codes, colours, border, background, set
  model/petscii_glyph_model.rb   the Unicode look-alike of a screen code (modern face)
  model/work_model.rb       a picture on the Exhibition: a canvas or a PETSCII work
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
  service/exhibition_service.rb             saving and uploading to the Exhibition, its limits
  service/upload_note_service.rb            the sysops' note of an upload (TTG::Feedback)
  pixelia_bbs.rb            the board's domain (PixeliaBBS): settings and services
lib/ui/
  logo.rb                   PIXELIA in blocks (Rubbs::Common::Text::BlockFont), a colour a letter, both faces
  glyph_keys.rb             glyph mode's keyboard, both faces
  wording.rb                what a caller is told about a save or an upload, both faces
  modern.rb                 UI::Modern::APP: commands, menus, help, statusbar and desktop
  modern/helpers.rb         what the caller does: opening windows, a piece, the canvas, saving
  modern/years_window.rb, packs_window.rb, files_window.rb, exhibition_window.rb   one window each
  modern/save_window.rb     the form that saves the canvas to the Exhibition
  modern/upload_window.rb   the title of an uploaded picture
  modern/canvas_widget.rb   the canvas's keys and mouse, and its window
  modern/canvas_panel.rb    drawing the canvas and its panel
  modern/viewer.rb          a piece or a work on the whole screen
  modern/art_lines.rb       rows of cells as ANSI lines (a PETSCII work framed in its border)
  petscii.rb                UI::Petscii: the C64 face, its masthead and main menu
  petscii/pen.rb            cells in C64 colours and reverse; ANSI cells to C64 ones
  petscii/canvas_view.rb    the canvas on a C64 screen, sending only what changed
  petscii/canvas.rb         painting on a C64
  petscii/gallery.rb        the 16colo.rs gallery on a C64
  petscii/exhibition.rb     the Exhibition on a C64: the works, a work, the upload
  petscii/work_screen.rb    a PETSCII work on the C64's own screen
```

## License

MIT, see the repository's `LICENSE`. The art in the gallery belongs to its artists and is shown
from [16colo.rs](https://16colo.rs).
