# TTG Gate BBS

One port for the whole Teletype BBS network. TTG Gate BBS is a dialing menu and
nothing more: the caller picks a board, and the gate hands the line on to that
board's own port with a telnet gateway of
[rubbs](https://git.teletypegames.org/engines/rubbs); when the board hangs up,
the caller is back at the menu. The boards run their own code on their own
ports, the gate only carries the bytes.

Besides our own boards it is a phone book of the world's other telnet BBSes:
**Global Discovery**, a searchable catalog that always shows which board
answered our last call and which did not, and dials any of them (see
[Global Discovery](#global-discovery)).

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
| G | Global Discovery, the world's PETSCII boards (see [On a Commodore 64](#on-a-commodore-64)) |
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

**Modern:** under the logo a two-way chooser, **Own Servers** | **Global
Discovery**; TAB (or the left and right arrows) turns from one to the other, and
each keeps its place. On Own Servers the arrows choose a board, RETURN or its
number dials it, `Q` or Esc hangs up. The rows show the board's colour bar,
name, tags and port; the description and the full address of the chosen one are
under the list. Global Discovery is described [below](#the-gate-ui).

**Commodore 64:** the switchboard (above); `G` turns to Global Discovery and
back, the number dials, `Q` or RUN/STOP hangs up.

Either way the board asks its own terminal question first: the gate reports the
caller's window size to it, so a modern terminal is its default, and a C64,
which has none, is taken for a C64.

## Global Discovery

Besides the boards of our own network, the gate is a phone book of the
world's other telnet BBSes: a searchable catalog that always shows which board
answered our last call and which did not, and dials any of them. The plan is in
the workspace, `TTG_DISCOVERY.md`.

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
| [CBBS Outpost](https://www.commodorebbs.com) (Commodore boards) | the site's public JSON (`/api/bbs`) | 198 | CBBS Outpost (commodorebbs.com) |

Together they give 561 boards (245 in more than one list; the CBBS Outpost
shares only a handful with the others). From the CBBS Outpost we take the facts
only: name, address, port, location, software, hardware, website and the date
of the entry; never the sysop, the e-mail, the owner, the screenshot, the
comment or the site's own online mark (our calls decide that). The import is
one request a day with our User-Agent, and its credit is on every board page it
names and on the Sources screen; its sysops can ask us to take an entry down.
The Telnet BBS Guide is in `config/discovery/sources.yml` too, switched off
until it answers our request for permission. The country of a board comes from
[DB-IP](https://db-ip.com)'s IP to Country Lite database (CC BY 4.0: "IP
Geolocation by DB-IP"), our own copy downloaded monthly into `data/geoip/`.

Each format has its own parser with a test fixture (synthetic samples in
`test/fixtures/discovery/`). One endpoint is one `host:port`: two lists naming
it are one board, and the fields come from the more trusted list
(`priority` in `sources.yml`; CBBS > nodelist > SBL > SyncTERM), the other value kept
too. The CBBS Outpost comes first: it lists only Commodore boards, kept by
their sysops, so for those its software and location are the best we have.
Two hosts on the same IP and port are one board with an alias; the same
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

**The C64-style call.** Our prober says it is an ANSI terminal, so a board that
adapts to its caller shows it ANSI, while a real Commodore 64 (a terminal
program behind a WiFi modem: plain TCP, no telnet) would get PETSCII. So a board
a source calls a PETSCII board (the CBBS Outpost's boards, a SyncTERM entry in
C64 mode, a PETSCII comment in the SBL: the tag `claims:petscii`), or whose
banner was PETSCII, is called a second time 30 s after its scheduled call
answered, as a C64 would: the same connection, one CR (0x0D) after 4 s of
silence, but every telnet option declined (WONT/DONT, no terminal type, no
window size), and a longer window for a real C64 behind tcpser that answers
late: up to 20 s for the first byte, reading until 25 s or 4 KB. It is the same
round, on the same claim of the host, so these boards get at most two calls a
day; a failed scheduled call gets no C64-style one, a silent C64-style call is
tried again the next day. These calls run on two workers of their own, so a
slow board never holds up the eight of the scheduled calls; a board called
with a shorter window that found no PETSCII gets one new call on its own. The
call is recorded as a probe of kind `c64`, with its own banner; it does not
count towards the state.

An answering board is called once a day (± 2 hours, so they spread), a failing
one again after 1, then 6, then 24 hours, a dead one weekly; a board that is
delisted and has been dead for a year is no longer called. At most 8 calls run
at once, and never two to the same host or IP.

From the calls: **online** (the last call answered and at least 80% of the
week's did), **flaky** (the last answered, fewer did), **down** (two failures
in a row), **dead** (no answer for 30 days; these go to the Graveyard and stay
there with their history) or **unknown** (not called yet).

The banner gives the encoding (`ansi`, `petscii`, `atascii`, `ascii`, by fixed
byte rules; plain text with a form feed, bell, backspace, tab or vertical tab,
or SUB at the end, is still `ascii`) and the software (`config/discovery/software.yml`, a table of
patterns). Tags come from a closed vocabulary only: the encoding, `sw:`, `net:`
(the nodelists, and the SBL's networks through `config/discovery/source-map.yml`),
`cc:`, the state, `new` and `veteran`, the telnet options `binary`, `naws` and
`ttype`, `src:`, and `claims:`.

**An encoding tag is measured, never claimed.** `petscii` comes only from a
PETSCII banner of one of our calls, the scheduled or the C64-style one; what a
source says is `claims:petscii` (or `claims:atascii`), a tag that is searched
(`claims:petscii` in the search) but not shown. A board whose C64-style call
gets ANSI or ASCII has no `petscii` tag whatever its list says; a board that
shows ANSI to our terminal and PETSCII to a C64 has both, and both banners are
kept: the modern face plays the ANSI one, the C64 face the PETSCII one.

### Opt-out

A sysop can ask to be left out: `config/discovery-optout.yml` takes a host or
an IP address under `hide` (never called, never shown) or `no_preview` (listed
and called, but its banner is never shown). The prober reads the file again
when it changes.

### The Gate UI

The modern face's Global Discovery side is a tree built from the tags, with no
hand-made category:

```
Global Discovery
├── Every board        all but the dead, online first, then by name
├── Search…            / anywhere: words and tags
├── Browse             by Terminal · Software · Country · Network, with counts
├── New this week      first seen by a list in the last 7 days
├── Random board       an online one
├── Recently died      dead in the last 30 days
├── Graveyard          every dead board, never deleted
└── Sources            the lists, their credits, DB-IP, opting out
```

A **list** shows a board a row: its state mark (`●` online, `◐` flaky, `✗`
down, `†` dead, `?` not called yet), name, software, country, and how long it
has not answered ("down for 3 days"). The arrows choose, left and right (PgUp,
PgDn) turn the pages, RETURN opens the board's page, `F` steps through the
states (online, flaky, down, unknown, all), `/` searches, `Q` goes back.

**Search** reads its words as tags where it can: `petscii hu online` is the
three tags together (the encoding, `cc:hu`, the state), and `synchronet`,
`fidonet`, `sbl` find `sw:`, `net:` and `src:` tags; the other words go to the
full-text index of names, sysops, places, software and hosts, each word the
start of a word there (`loun` finds a Lounge). The dead boards are left out
unless the search says `all` (or `dead`). FTN mailers (`sw:ftn-mailer`: mail
programs answering a nodelist's telnet flag, not BBSes) are left out of every
list unless the search names that tag.

A **board page** has the address, the state, the last answer and, for a failing
board, why our server did not reach it (a name that does not resolve is not a
firewall); a strip of the last 30 days (`█` it answered that day, `·` it did
not, blank: not called); every field with the list it came from (or "our call"
for what its banner said, DB-IP for the country); the FTN address, the lists
that name it and its tags. `B` plays the first screen of its stored banner (only
its text, colours and cursor moves; never for a board whose sysop asked for no
preview, and a PETSCII banner only on the C64 face). RETURN or `D` dials it.

### On a Commodore 64

`G` on the C64 switchboard turns to Global Discovery (and back): the same
switchboard, frame, rain and pages, eight nodes a page, but a node is a board of
the catalog with its state mark where our boards have their colour block (a
green ball online, a yellow one flaky, a red cross down, a grey cross dead, `?`
not called yet), its country at the edge, and its address, software and state
under the frame. Only PETSCII boards are on it (measured: the `petscii` tag of
a call's banner, see above), and not the dead ones (the gate
carries the bytes as they are, and an ANSI board on a C64 is noise): the home
menu has every PETSCII board, Search (`/` anywhere, a 40-column input line;
`all` takes the dead in), Browse by Software, Country and Network (by Terminal
would be PETSCII only), New this week, a Random board, Recently died, the
Graveyard and the Sources. RETURN opens a board's page (the 30-day strip, the
fields, the tags, the lists); there RETURN dials and `B` shows the first screen
of a PETSCII banner. Moving between the nodes sends only the changed cells, as
on our own switchboard (a whole screen about 1.3 KB, a step under 360 bytes).

### Dialling

Only a board of the catalog can be dialled, by its page: there is no free
`host:port`, so the gate is no open telnet relay. The rules
(`Discovery::DialService`):

- **10 dials in 10 minutes a caller.** A caller is its IP address; a line from
  a private address (bbsweb carries all its callers from the same host) counts
  by its connection.
- **3 lines to one host at once** from the gate.
- On the modern face a board made for a C64 only (PETSCII and no other
  encoding seen) asks first: it would be noise there. The C64 face dials
  PETSCII boards only. A dead board asks first too, on either face.
- After the board hangs up (and a key), the caller is back on the board's page,
  and `Q` returns to the same place of the same list or search.
- The dial is recorded as a probe of kind `dial`: `ok` when the board sent
  something, `silent`, `closed`, `refused`, `timeout` or `dns_fail` as for the
  prober. It counts towards the state like a probe (a failed dial after a failed
  probe turns a board down) and a failed one asks the prober to call the board
  at once; a dial leaves the stored banner and telnet options as they are.

The gate opens the catalog read only but for these dial records. The dials in
progress go to `data/gate-dials.json`; the prober puts them into
`data/discovery-metrics.prom` as `ttg_gate_bbs_discovery_dials_live`, with the
dials of the last hour a result (`ttg_gate_bbs_discovery_dials_last_hour`).

### Running it

```bash
bin/discovery-import            # fetch every list into data/discovery.sqlite3
bin/discovery-report            # boards a source and their overlap, states, PETSCII measured vs claimed, tags
bin/discovery-prober --limit 20 # 20 calls, then stop (without --limit: a daemon)
bin/discovery-test              # the tests (minitest)
```

On the server the prober runs as the `ttg-gate-bbs-prober` service of
`compose.yaml` (128 MB, half a CPU, no port); the import runs daily in its
container from cron (`docker exec ttg-gate-bbs-prober bin/discovery-import`).
Both write `data/discovery-metrics.prom` in the Prometheus text format (every
name starts `ttg_gate_bbs_discovery_`): the boards a state (`boards`), the
prober's work (`probes_in_flight`, `probes_due`, `next_probe_due_seconds`,
`probes_total{result,kind}` counted in the catalog (`kind` is `scheduled`,
`c64` or `dial`), `probes_last_hour`,
`probe_duration_seconds_avg_last_hour`, `probe_duration_seconds_max_last_hour`,
`banner_bytes_avg_last_hour`, `last_probe_timestamp_seconds`), the answering
boards by `boards_by_encoding`, `boards_by_network`, `boards_by_country` and
`boards_by_software` (the top 15 and `other`), the sources (`source_records`,
`source_last_import_timestamp_seconds`, `source_failing`), the gate's dials
(`dials_live`, `dials_last_hour`), and `geoip_age_seconds`, `db_bytes`,
`optout_hosts{level}`.

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
  ui/modern.rb                         the modern face: Own Servers | Global Discovery
  ui/modern/style.rb                   its palette, the logo and the chooser
  ui/modern/selector.rb                the dialing menu of our own boards on an ANSI terminal
  ui/modern/discovery/                 Global Discovery: home, menus, lists, the board page, search, sources
  ui/petscii.rb                        the PETSCII face: keys, dialling, goodbye
  ui/petscii/switchboard.rb            the C64 menu: logo, rain, the nodes, pages
  ui/petscii/discovery.rb              Global Discovery on the C64: menus, search, lists, pages, dialling
  ui/petscii/discovery_board.rb        its switchboard: a state mark a node
  ui/petscii/board_screen.rb           a board's page on the C64
  ui/petscii/canvas.rb                 UI::Petscii::Canvas = rubbs' BBS::Petscii::Canvas (40×25, raw PETSCII)
  ui/petscii/screen.rb                 the C64 line of one call: raw out, keys in
  ui/colors.rb                         a board's accent on either face
  ui/dial.rb                           hands the line to a board (BBS::Gateway), by the dial rules for the catalog
  domain/discovery.rb                  requires Global Discovery
  domain/discovery/root.rb             its composition root (Discovery::Root)
  domain/discovery/model/              a source record, a probe result, a board state, a source; a listing, a board page, a search
  domain/discovery/parser/             one parser a list format
  domain/discovery/repository/         the SQLite catalog, the config, the opt-outs, HTTP, zip, DB-IP; the gate's reads
  domain/discovery/service/            import, prober, telnet probe, state rules, banner rules, tags, report;
                                       the gate's browse, banner preview and dial rules
```

## Deploy

A push to master deploys from Woodpecker: RuboCop and the Discovery tests, a compose check, then
`ci-deploy ttg-gate-bbs` on the server (infra/host-config), which runs the stack in
`/srv/stacks/ttg-gate-bbs`. The entrypoint updates rubbs on start.

## License

MIT, © 2026 Teletype Games.
