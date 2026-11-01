# TTG Gate BBS

One port for the whole Teletype BBS network. TTG Gate BBS is a dialing menu and
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

The C64 face is drawn in the uppercase/graphics character set of the C64, in
the greens of a phosphor screen: code rain falls down the whole screen, behind
TTG GATE in half-block letters, the tagline, the frame and the info, and shows
in the open columns beside the frame and in the gaps between. The boards are
the nodes of a list in a thin frame, one row each: the key, a block of the
board's colour, the name, a dotted leader and the port. The chosen node is lit
in green, and its address, tags and link state are under the frame.

| Key | |
|---|---|
| CRSR up / down | move between the nodes; past the first or the last one, the page turns |
| CRSR left / right, + / - | the previous / next page |
| RETURN or 1-8 | jack in: the node flashes, the HANDSHAKE bar fills, the line goes to the board |
| Q or RUN/STOP | hang up |

A page holds eight nodes. The empty places of the last page are **unassigned**,
so a new board in `config/boards.yml` just fills the next one; past eight the
menu turns into pages, PAGE 2/3 in the frame. The colour block of a node is the
C64 colour nearest to the board's `accent`.

The screen goes out as raw PETSCII (`Session#write_raw`, rubbs 0.26.0), past
the encoder of rubbs, which speaks the lowercase set: the whole screen once
(about 1 KB), then only the cells that change, since a C64 line behind a modem
is slow. The rain falls a row every 0.5 s while the caller thinks, about 180
bytes a step, the cursor stepping from cell to nearest cell; the call still
ends after the session's idle time. Before the line goes to a board the gate
switches back to the lowercase set. `UI::Petscii::Canvas` turns a grid of cells
into these bytes, `UI::Petscii::Switchboard` draws the menu on it.

## Running

**Docker Compose:**

```bash
docker compose up --build
```

**Directly (Ruby 3.x):**

```bash
bundle install
TTG_GATE_BBS_GATEWAY_HOST=teletypegames.org ruby bbs.rb
```

Connect:

```bash
telnet localhost 2399      # compose
telnet localhost 2323      # directly (BBS_PORT)
```

## Configuration

| Variable | Default | |
|---|---|---|
| `TTG_GATE_BBS_GATEWAY_HOST` | `host.docker.internal` | where the boards are dialled; compose maps it to the host |
| `TTG_GATE_BBS_PUBLIC_HOST` | `teletypegames.org` | the address shown with every board |
| `TTG_GATE_BBS_BOARDS` | `config/boards.yml` | the boards list |
| `TTG_GATE_BBS_DISCORD_WEBHOOK` | empty | Discovery: where import alerts go; empty: off |
| `TTG_GATE_BBS_DATA` | `data` | Discovery: the data folder |
| `TTG_GATE_BBS_DISCOVERY_DB` | `data/discovery.sqlite3` | Discovery: the catalog |
| `TTG_GATE_BBS_DISCOVERY_OPTOUT` | `config/discovery-optout.yml` | Discovery: the opt-out list |
| `BBS_PORT` | `2323` | the port inside the container (rubbs) |
| `BBS_MAX_SESSIONS` | `50` | callers at once (rubbs) |

`env-example` lists them all.

### The boards list

`config/boards.yml` holds the boards in the order of the menu, with the names,
descriptions, tags and accent colours of their bbsweb cards:

```yaml
boards:
  - id: ttg-blog-bbs
    name: "TTG Blog BBS"
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

## Global Discovery

Besides the boards of our own network, the gate is growing a phone book of the
world's other telnet BBSes: a searchable catalog that always shows which board
answered our last call and which did not. The plan is in the workspace,
`TTG_DISCOVERY.md`. The catalog and its prober run now; the gate does not show
them yet (the menu, the search and the dialling come next).

Everything in the catalog is generated: a field comes from a source list, from
our own call to the board, from DNS or from a fixed rule table, never from a
hand-written category, and no language model is involved. Only telnet: no SSH,
rlogin or web addresses.

### Sources

The daily import (`bin/discovery-import`) reads the lists below, the ones a
program can download and read. Nothing is scanned: we only call the addresses
these lists publish.

| Source | Format | Telnet boards (2026-11-01) | Credit |
|---|---|---|---|
| [FidoNet nodelist](https://nodelist.fidonet.cc) (Z2DAILY, zones 1-4) | FTS-5000 nodelist, the ITN flag | 95 | FidoNet nodelist, via NodelistDB |
| [fsxNet nodelist](https://fsxnet.nz) | nodelist in the info pack | 38 | fsxNet |
| [Micronet nodelist](https://minftn.outpostbbs.net) | nodelist | 14 | Micronet |
| [Synchronet BBS List](https://www.synchro.net/sbbslist.html) | HTML export of Vertrauen | 235 | Synchronet BBS List, synchro.net |
| [SyncTERM BBS list](http://synchro.net/syncterm.lst) | SyncTERM ini (the SBL export) | 243 | SyncTERM BBS list, synchro.net |

Together they give 366 boards (245 in more than one list). The Telnet BBS Guide
and the CBBS Outpost are in `config/discovery/sources.yml` too, switched off
until they answer our request for permission. The country of a board comes from
[DB-IP](https://db-ip.com)'s IP to Country Lite database (CC BY 4.0: "IP
Geolocation by DB-IP"), our own copy downloaded monthly into `data/geoip/`.

Each format has its own parser with a test fixture (synthetic samples in
`test/fixtures/discovery/`). One endpoint is one `host:port`: two lists naming
it are one board, and the fields come from the more trusted list
(`priority` in `sources.yml`; nodelist > SBL > SyncTERM), the other value kept
too. Two hosts on the same IP and port are one board with an alias; the same
name on two addresses is two boards. A board no list names any more is
**delisted** but still called. If a list loses more than half of its records
from one day to the next, the import does not apply it, keeps the old records
and posts an alert to Discord (`TTG_GATE_BBS_DISCORD_WEBHOOK`).

### How we call a board

The prober (`bin/discovery-prober`, its own container `ttg-gate-bbs-prober`)
calls each board like this:

1. It looks the host up (A, then AAAA) and connects, giving up after 10 s.
2. It answers the telnet questions with fixed replies: the terminal type is
   `ANSI`, the window 80×25, every other option is declined.
3. It reads for at most 8 s or 4 KB. If nothing comes in 4 s, it sends one
   Enter, nothing else. **It never logs in.**
4. It hangs up. The result is `ok` (a banner came), `silent` (connected, no
   bytes), `closed`, `refused`, `timeout` or `dns_fail`.

An answering board is called once a day (± 2 hours, so they spread), a failing
one again after 1, then 6, then 24 hours, a dead one weekly; a board that is
delisted and has been dead for a year is no longer called. At most 8 calls run
at once, and never two to the same host or IP.

From the calls: **online** (the last call answered and at least 80% of the
week's did), **flaky** (the last answered, fewer did), **down** (two failures
in a row), **dead** (no answer for 30 days; these go to the Graveyard and stay
there with their history) or **unknown** (not called yet).

The banner gives the encoding (`ansi`, `petscii`, `atascii`, `ascii`, by fixed
byte rules) and the software (`config/discovery/software.yml`, a table of
patterns). Tags come from a closed vocabulary only: the encoding, `sw:`, `net:`
(the nodelists, and the SBL's networks through `config/discovery/source-map.yml`),
`cc:`, the state, `new` and `veteran`, the telnet options `binary`, `naws` and
`ttype`, and `src:`.

### Opt-out

A sysop can ask to be left out: `config/discovery-optout.yml` takes a host or
an IP address under `hide` (never called, never shown) or `no_preview` (listed
and called, but its banner is never shown). The prober reads the file again
when it changes.

### Running it

```bash
bin/discovery-import            # fetch every list into data/discovery.sqlite3
bin/discovery-report            # boards a source and their overlap, states, tags
bin/discovery-prober --limit 20 # 20 calls, then stop (without --limit: a daemon)
bin/discovery-test              # the tests (minitest)
```

On the server the prober runs as the `ttg-gate-bbs-prober` service of
`compose.yaml` (128 MB, half a CPU, no port); the import runs daily in its
container from cron (`docker exec ttg-gate-bbs-prober bin/discovery-import`).
Both write `data/discovery-metrics.prom` in the Prometheus text format: the
boards a state, the probes of the last hour a result, the records a source.

## Project structure

```
bbs.rb                                 entry point: the terminal question, then a face
bin/discovery-import                   Discovery: the daily import of the source lists
bin/discovery-prober                   Discovery: the prober daemon
bin/discovery-report                   Discovery: the catalog in numbers
bin/discovery-test                     Discovery: the tests (test/discovery/)
config/boards.yml                      the boards of the menu
config/discovery/                      Discovery: sources, software signatures, source-to-tag rules
config/discovery-optout.yml            Discovery: the sysops who asked to be left out
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
  domain/discovery.rb                  requires Global Discovery
  domain/discovery/root.rb             its composition root (Discovery::Root)
  domain/discovery/model/              a source record, a probe result, a board state, a source
  domain/discovery/parser/             one parser a list format
  domain/discovery/repository/         the SQLite catalog, the config, the opt-outs, HTTP, zip, DB-IP
  domain/discovery/service/            import, prober, telnet probe, state rules, banner rules, tags, report
```

## Deploy

A push to master deploys from Woodpecker: RuboCop and the Discovery tests, a compose check, then
`ci-deploy ttg-gate-bbs` on the server (infra/host-config), which runs the stack in
`/srv/stacks/ttg-gate-bbs`. The entrypoint updates rubbs on start.

## License

MIT, © 2026 Teletype Games.
