# TTG Gate

One port for the whole Teletype BBS network. TTG Gate is a dialing menu and
nothing more: the caller picks a board, and the gate hands the line on to that
board's own port with a telnet gateway of
[rubbs](https://git.teletypegames.org/engines/rubbs); when the board hangs up,
the caller is back at the menu. The boards run their own code on their own
ports, the gate only carries the bytes.

It has two faces on one port, like every board of the network: a **modern** one
for ANSI terminals, after the list of [bbsweb](https://bbsweb.teletypegames.org)
(the logo, a row a board in its own colour, the chosen board's description
under the list), and a **Commodore 64** one in PETSCII, 40×25, for the boards
that have a C64 face.

### The C64 switchboard

The C64 face is drawn in the uppercase/graphics character set of the C64, where
the card suits, the balls, the rounded corners, the triangles and the quarter
blocks are: TTG GATE in fat rainbow letters with a checkered shadow, twinkling
stars around it, and the boards as candy buttons in their own colours, two by
four. The chosen one has a heart on each side, and its address and tags are
under the buttons.

| Key | |
|---|---|
| CRSR | move between the buttons; past the first or the last row, the page turns |
| RETURN or 1-8 | dial: the button flashes, the dots roll, the line goes to the board |
| + / - | the next / previous page |
| Q or RUN/STOP | hang up |

A page holds eight buttons. The empty places of the last page are grey **free
lines**, so a new board in `config/boards.yml` just fills the next one; past
eight the menu turns into pages, with ● ○ dots under the buttons. The colour of
a button is the C64 colour nearest to the board's `accent`.

The screen goes out as raw PETSCII (`Session#write_raw`, rubbs 0.26.0), past
the encoder of rubbs, which speaks the lowercase set: the whole screen once
(about 1.3 KB), then only the cells that change, since a C64 line behind a
modem is slow. The stars twinkle every 1.5 s while the caller thinks; the call
still ends after the session's idle time. Before the line goes to a board the
gate switches back to the lowercase set. `UI::Petscii::Canvas` turns a grid of
cells into these bytes, `UI::Petscii::Switchboard` draws the menu on it.

## Running

**Docker Compose:**

```bash
docker compose up --build
```

**Directly (Ruby 3.x):**

```bash
bundle install
TTGGATE_GATEWAY_HOST=teletypegames.org ruby bbs.rb
```

Connect:

```bash
telnet localhost 2399      # compose
telnet localhost 2323      # directly (BBS_PORT)
```

## Configuration

| Variable | Default | |
|---|---|---|
| `TTGGATE_GATEWAY_HOST` | `host.docker.internal` | where the boards are dialled; compose maps it to the host |
| `TTGGATE_PUBLIC_HOST` | `teletypegames.org` | the address shown with every board |
| `TTGGATE_BOARDS` | `config/boards.yml` | the boards list |
| `BBS_PORT` | `2323` | the port inside the container (rubbs) |
| `BBS_MAX_SESSIONS` | `50` | callers at once (rubbs) |

`env-example` lists them all.

### The boards list

`config/boards.yml` holds the boards in the order of the menu, with the names,
descriptions, tags and accent colours of their bbsweb cards:

```yaml
boards:
  - id: ttgblog
    name: "TTGBLOG"
    summary: "The Teletype Games blog on a telnet line: …"
    tags: ["blog", "news", "C64"]
    port: 2328
    accent: "#5fd7af"
    petscii: true
    enabled: true
```

A new board of the network gets an entry here (see the BBS server procedure in
devarea, `procedures/bbs-server-creation.md`); a push deploys it. `petscii:
false` keeps a board off the C64 menu, `enabled: false` off both.

## Interface

**Modern:** the arrows choose a board, RETURN or its number dials it, `Q` or
Esc hangs up. The rows show the board's colour bar, name, tags and port; the
description and the full address of the chosen one are under the list.

**Commodore 64:** the logo in reversed blocks, the boards numbered in their own
colours (the nearest of the C64's) with their tags under them. The number dials,
`Q` or RUN/STOP hangs up.

Either way the board asks its own terminal question first: the gate reports the
caller's window size to it, so a modern terminal is its default, and a C64,
which has none, is taken for a C64.

## Project structure

```
bbs.rb                                 entry point: the terminal question, then a face
config/boards.yml                      the boards of the menu
lib/
  domain.rb                            requires the domain
  domain/model/board_model.rb          one board of the list
  domain/repository/board_repository.rb  config/boards.yml, read once
  domain/service/directory_service.rb  the boards a caller can dial
  domain/ttg_gate_bbs.rb               the composition root (TTGGateBBS)
  ui/modern.rb                         the modern face
  ui/modern/selector.rb                the dialing menu on an ANSI terminal
  ui/petscii.rb                        the PETSCII face: keys, dialling, goodbye
  ui/petscii/switchboard.rb            the C64 menu: logo, stars, candy buttons, pages
  ui/petscii/canvas.rb                 40×25 cells in the graphics set → raw PETSCII
  ui/petscii/screen.rb                 the C64 line of one call: raw out, keys in
  ui/colors.rb                         a board's accent on either face
  ui/dial.rb                           hands the line to a board (BBS::Gateway)
```

## Deploy

A push to master deploys from Woodpecker: RuboCop, a compose check, then
`ci-deploy ttggate` on the server (infra/host-config), which runs the stack in
`/srv/stacks/ttggate`. The entrypoint updates rubbs on start.

## License

MIT, © 2026 Teletype Games.
