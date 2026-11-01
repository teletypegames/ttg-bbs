# Pixelia BBS

The PETSCII & ANSI art gallery: classic 8-bit masterpieces and a collaborative
text-art canvas for your terminal or Commodore 64. An art board of
[Teletype Games](https://teletypegames.org), powered by
[rubbs](https://git.teletypegames.org/engines/rubbs).

It has two faces on one port, like every board of the network:

- a **modern** one for ANSI terminals: a desktop with windows, the mouse, the
  gallery in 80 columns and 16 colours, the canvas in a window with a palette;
- a **Commodore 64** one in PETSCII, 40×25: cursor menus of rubbs
  (`BBS::Selector`: CRSR and RETURN, or the key or number as before) for the
  menu and the lists, the gallery 40 columns at a time and the canvas on the
  C64's own screen.

## The gallery

The [16colo.rs](https://16colo.rs) archive of the ANSI and ASCII scene, read on
demand from its public API (`api.16colo.rs/v1`): the years, a year's packs, a
pack's files, with the artists and groups and the 16colo.rs address of each.
Nothing is mirrored into the repository and nothing is fetched ahead: a listing
when it is opened, a file when it is shown. Listings stay in memory for
`PIXELIA_BBS_API_TTL` seconds; files are cached in `data/cache/` up to
`PIXELIA_BBS_CACHE_MB`, the least recently used going first. Requests carry a
`User-Agent` naming the board and teletypegames.org.

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
temporary file.

- **Modern:** arrows move, typing paints, Enter paints the brush, Backspace and
  Delete rub out, F7/F8 ink, F9 or Ctrl-R reverse, Insert or Ctrl-G glyph mode,
  Ctrl-S save to the Wall, Ctrl-Z undo. The mouse places the cursor, paints by
  dragging or with a right click, and picks inks and brushes in the panel.
- **C64:** CRSR moves, typing paints, DEL rubs out, F3/F4 ink, F5 reverse, F6
  glyph mode; RETURN (or RUN/STOP, ←) opens the command line on the status row
  (ink, reverse, glyphs, save, help, quit). F1 and F7 stay free, UltimateTerm
  keeps them. A C64's own graphics keys do not reach the board, so in **glyph
  mode** the letter keys paint the graphics, laid out like the shapes on the
  keyboard (`q w e` / `a s d` / `z x c` are the corners, tees and cross of a box,
  `g` █, `t` ▀, `b` ▄, `y` ▌, `h` ▐, `u` ▒ …). The screen shows 24 canvas rows
  and a status line, and scrolls by one when the cursor goes to the last row.

## The Wall

The canvas saved under a title (32 characters) and a handle (16), newest first,
one JSON file each in `data/works/`. A caller saves at most once in
`PIXELIA_BBS_WALL_COOLDOWN` seconds.

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
| `PIXELIA_BBS_DATA` | `data` | the canvas, the Wall, the archive and the cache |
| `PIXELIA_BBS_API_URL` | `https://api.16colo.rs` | the 16colo.rs API |
| `PIXELIA_BBS_SITE_URL` | `https://16colo.rs` | where the raw files are |
| `PIXELIA_BBS_USER_AGENT` | `PixeliaBBS/1.0 (+https://teletypegames.org; …)` | how the board introduces itself |
| `PIXELIA_BBS_API_TTL` | `3600` | seconds a listing stays in memory |
| `PIXELIA_BBS_MAX_FILE_KB` | `512` | the largest art file fetched |
| `PIXELIA_BBS_CACHE_MB` | `100` | the disk cache of art files |
| `PIXELIA_BBS_MAX_ROWS` | `1000` | a piece is cut after this many rows |
| `PIXELIA_BBS_PAINT_RATE` | `20` | cells a second one caller may paint |
| `PIXELIA_BBS_WALL_COOLDOWN` | `300` | seconds between two saves of one caller |

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
when no board answers, the script clears the file itself.

## Project structure

```
bbs.rb                      entry point: BBS.configure + BBS::Terminal.flow
bin/works, bin/canvas       admin scripts, run with docker exec
lib/domain.rb               requires the domain in dependency order
lib/domain/
  model/color_model.rb      the sixteen C64 colours (ANSI and xterm-256 too)
  model/glyph_model.rb      the characters a canvas cell may hold
  model/canvas_model.rb     a 40×25 picture, frozen; its JSON
  model/work_model.rb       a picture on the Wall
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
  service/wall_service.rb                   saving to the Wall, its limits
  pixelia_bbs.rb            the composition root (PixeliaBBS)
lib/ui/
  logo.rb                   PIXELIA in blocks (BBS::BlockFont), a colour a letter, both faces
  glyph_keys.rb             glyph mode's keyboard, both faces
  wall_text.rb              what a caller is told about a save, both faces
  modern.rb                 UI::Modern: the rubbs Application
  modern/canvas_widget.rb   the canvas and its panel, and its window
  modern/viewer.rb          a piece or a work on the whole screen
  modern/art_lines.rb       rows of cells as ANSI lines
  modern/logo_widget.rb     the logo on the desktop
  petscii.rb                UI::Petscii: the C64 board and its menu
  petscii/screen.rb         the 40×25 screen: rubbs' BBS::Petscii::Screen
  petscii/pen.rb            cells in C64 colours and reverse; ANSI cells to C64 ones
  petscii/canvas_view.rb    the canvas on a C64 screen, sending only what changed
  petscii/canvas.rb         painting on a C64
  petscii/gallery.rb        the 16colo.rs gallery on a C64
  petscii/wall.rb           the Wall on a C64
```

## License

MIT, see `LICENSE`. The art in the gallery belongs to its artists and is shown
from [16colo.rs](https://16colo.rs).
