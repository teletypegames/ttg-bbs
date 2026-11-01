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

### The C64 face

The C64 face is drawn in the lower/upper character set of the C64 (names,
hosts and labels keep their case), in its sixteen colours, one frame around
every screen:

- **row 0**, the header: `TTG GATE` letter by letter in reversed colours, the
  node number (the C64 callers on the gate now) and the clock;
- **row 1**, the two tabs, `OWN SERVERS` and `GLOBAL DISCOVERY`: the active one
  a reversed band in its colour (Own yellow, Discovery light green), the other
  dim with its yellow letter, and on the right the boards online now;
- **row 2**, the active tab's sub-menu: on Global Discovery `/Find`, `Browse`,
  `New`, `Random`, `Sources`, their keys yellow,
  the lit one a reversed bar (cyan while the menu has the focus); on Own
  Servers a line of how many boards there are and how they are dialled;
- **rows 3-23**, the content, across all 40 columns;
- **row 24**, the hint bar: the keys of the screen in yellow.

Each screen of the content starts with its title row in its own colour (Own
Servers yellow, Discovery light green, Search white, Browse orange, New purple,
Sources cyan, a board's page in the
colour of its state) with a count and the page on the right. A board's
address is never cut: past the row it goes on in the next one, broken after a
dot or before the port.

| Key | |
|---|---|
| O / D or G | the tab Own Servers / Global Discovery (it opens All PETSCII), from anywhere |
| CRSR up / down | move the lit row of a list (past the edge of a page, the page turns); on Global Discovery CRSR up from the top of a list (or from a page) goes to the sub-menu, and there CRSR down goes back |
| CRSR left / right | in the sub-menu: move its bar |
| RETURN | open the place of the sub-menu; in a list open the board's page (dial our own board); on a board's page dial it |
| a yellow sign | that place from anywhere: `/` Find, `B`rowse, `N`ew, `R`andom, `S`ources (or `U`, as before), Browse's soft`W`are, `C`ountry, networ`K`, `H`elp, `Q`uit |
| 1-9, 0 | that row of the page (on Own Servers: dial it) |
| + / - | the next / previous page |
| F | in a list: the state filter, alive (all but the dead) → online → flaky → down → not called yet |
| B | on a board's page: its PETSCII banner (here `B` is not Browse) |
| ← or RUN/STOP | back a screen; from a section to Own Servers, and from there hang up |

`S` opens the Sources now (it was Search before the tabs; Find is `/`).

**Own Servers** lists our boards with a C64 face, ten a page: the number, a
block of the board's colour (the C64 colour nearest to its `accent`), the name,
a dotted leader and the port, the lit one a cyan bar; under a rule the lit
board's name, description, address and tags. **Global Discovery**'s lists show
ten boards a page (number, state mark, name, country, software), and under
them the lit board's name, whole address, state, latency and country,
software and terminals. RETURN or its digit dials it: the
row flashes, the HANDSHAKE bar fills the hint bar, the line goes to the board.

The screen goes out as raw PETSCII (`Session#write_raw`), past the encoder of
rubbs, which speaks the lowercase set. Each change is drawn on a new
`UI::Petscii::Canvas` (rubbs' `BBS::Petscii::Canvas`) and only the cells that
differ from what the C64 shows go out, row by row (`UI::Petscii::Diff`), or the
whole screen when that is shorter: a first screen is 0.95-1.15 KB, a step in a
list 200-360 bytes, the focus moving between the sub-menu and a list about 150.
While the caller thinks only the clock changes, once a minute; the call still
ends after the session's idle time. Before the line goes to a board the gate
switches back to the lowercase set, and the whole screen comes back, at the
same place, when the board hangs up.

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
| `TTG_GATE_BBS_DIAL_WINDOW` | `600` | Discovery: the window of the per-caller dial limit, seconds |
| `TTG_GATE_BBS_DIAL_PER_CALLER` | `10` | Discovery: the dials one caller may make in the window |
| `TTG_GATE_BBS_DIAL_PER_HOST` | `3` | Discovery: the lines from the gate to one host at once |
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

**Commodore 64:** the frame and the tabs ([above](#the-c64-face)); `D`
turns to Global Discovery (the All PETSCII list of Browse), `O` back to our own boards, the number dials, `Q`
hangs up.

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
| [Telnet BBS Guide](https://www.telnetbbsguide.com) | the monthly IBBSmmyy.ZIP: its full listing and EtherTerm phonebook | 1060 | Telnet BBS Guide (telnetbbsguide.com), used with permission |

Together they give about 1380 boards (about 350 in more than one list; the CBBS
Outpost shares only a handful with the others, and some 820 are only in the
Telnet BBS Guide). From the CBBS Outpost we take the facts
only: name, address, port, location, software, hardware, website and the date
of the entry; never the sysop, the e-mail, the owner, the screenshot, the
comment or the site's own online mark (our calls decide that). The import is
one request a day with our User-Agent, and its credit is on every board page it
names and on the Sources screen; its sysops can ask us to take an entry down.
The Telnet BBS Guide is used with its permission (2026-11-01): the "official"
monthly list, the one it publishes for distribution, found by its link on the
download page (the file name changes each month; the daily list is for
personal use and never read). From its full listing we take the name, the
telnet `host:port`, the location, the software, the website and the date of the
entry, and the names as their sysops write them from the phonebook of the zip;
never the e-mail or the description (a description only tells whether it names
PETSCII), and the SSH, web-only and dial-up entries are left out. The country of a board comes from
[DB-IP](https://db-ip.com)'s IP to Country Lite database (CC BY 4.0: "IP
Geolocation by DB-IP"), our own copy downloaded monthly into `data/geoip/`.

Each format has its own parser with a test fixture (synthetic samples in
`test/fixtures/discovery/`). One endpoint is one `host:port`: two lists naming
it are one board, and the fields come from the more trusted list
(`priority` in `sources.yml`; CBBS > nodelist > SBL > TBG > SyncTERM), the other value kept
too. The CBBS Outpost comes first: it lists only Commodore boards, kept by
their sysops, so for those its software and location are the best we have.
The Telnet BBS Guide is the largest list, but it is edited by hand, once a
month, and an entry may not have changed for years, while the nodelists and the
SBL are rebuilt daily or weekly; it still has more than SyncTERM (location,
software, website), which is an export of the SBL.
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
C64 mode, a PETSCII comment in the SBL, a Telnet BBS Guide entry naming PETSCII
or running a Commodore BBS program: the tag `claims:petscii`), or whose
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

`D` or `G` (or the `GLOBAL DISCOVERY` tab) opens Global Discovery in the frame of the
C64 face on `ALL PETSCII` (the first lists of Browse): every PETSCII board in
every state, online and flaky first, then down, not called and dead, then by
name, ten a page. The row under the title shows the
filter as chips (`PETSCII`, and the state: `All`, or what `F` chose), a dark
grey header (`Nr S Name CC Software`), then a board a row: its number, its state
mark (a half block: light green online, yellow flaky, red down, grey dead, dark
grey not called yet), its name, its country and its software; the
lit one a light blue bar. Under a rule the lit board's name, host and port,
state with the latency of the last answer and the country, software and
terminals, and the legend of the marks. `All` (Browse) lists every board of
the catalog, every encoding (chip `Any`): a board without PETSCII has a dark
grey name, its encoding (`ANSI`, `ASCII`) in the software column, and its page
says the C64 cannot dial it. On the other lists only PETSCII boards are shown
(measured: the `petscii` tag of a call's banner, see above), and not the dead
ones but in All, All PETSCII, Recently died, the Graveyard or a search with `all` (the gate
carries the bytes as they are, and an ANSI board on a C64 is noise).

Find (`/`) reads its words on the hint row (`all` takes the dead in);
Browse lists All, All PETSCII, Software, Country and Network with their counts (by Terminal
would be PETSCII only), each a list of tags and each tag a list of boards;
New, Random, Died and Graves are the lists of the modern face. RETURN opens a
**board's page**: the address, the last answer and its latency, why our server
did not reach a failing board, `30 days` with the 30-day strip (a green block
it answered that day, red it did not, a dark grey checker not called), the
fields (a long value wraps) with the list each came from in dark grey (`BANNER` or `CALL` for what
our call saw, `DB-IP` for the country), the terminals and the lists, the tags
as chips, and the buttons: RETURN dials, `B` shows the first screen of a
PETSCII banner. **Sources** has each list two rows: its name in its colour, a
bar of its records against the largest list's and the count; whether its last
import went well (`OK`, or the error in red), its format and terms, how long
ago; then the boards of the catalog and how many more than one list names,
PETSCII measured (green) against claimed by a list (purple), and the credit of
DB-IP for the countries.

### Dialling

Only a board of the catalog can be dialled, by its page: there is no free
`host:port`, so the gate is no open telnet relay. The rules
(`Discovery::DialService`):

- **10 dials in 10 minutes a caller.** A caller is its IP address; a line from
  a private address (bbsweb carries all its callers from the same host) counts
  by its connection.
- **3 lines to one host at once** from the gate.
- Both limits are the defaults of `TTG_GATE_BBS_DIAL_WINDOW`,
  `TTG_GATE_BBS_DIAL_PER_CALLER` and `TTG_GATE_BBS_DIAL_PER_HOST` (a value that
  is not a positive number keeps the default, with a warning).
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

The gate opens the catalog read only but for these dial records. Besides the
probe, each dial that went leaves a row in `dials` (when it ended, the board,
the face, the result, the seconds connected, the bytes the board sent through
the gate; the gateway does not count the caller's side), and each refused one a
row in `dial_refusals` (when, the reason: `rate`, `busy`, `not_petscii` or
`unknown`, the board, the face: `modern` or `c64`). Neither has anything of the
caller. Both keep 30 days; the refusals that go are added to running totals in
`meta`, so the counts only grow.

The dials in progress go to `data/gate-dials.json`, with the limits, the lines
in use to the busiest host, and the dial times in the window of each caller (a
list of lists: no caller is named). The prober reads it and the tables into
`data/discovery-metrics.prom` (every name starts `ttg_gate_bbs_discovery_`):

| Metric | |
|---|---|
| `dials_live` | dials in progress |
| `dials_last_hour{result}`, `dials_total{result}` | dials of the last hour, and every dial (its probes of kind `dial`) |
| `dial_limit{kind}` | the limits: `window_seconds`, `per_caller`, `per_host` |
| `dial_caller_max_in_window` | the most dials one caller has in the current window (0 … per_caller) |
| `dial_callers_at_limit` | callers at the per-caller limit now |
| `dial_host_lines_max` | the most lines in use to one host now (0 … per_host) |
| `dial_refusals_total{reason,face}` | every refused dial |
| `dial_refusals_last_hour{reason}` | refused dials of the last hour |
| `dial_seconds_last_hour`, `dial_seconds_avg_last_hour` | seconds on the line of the dials that ended in the last hour, summed and on average |
| `dial_bytes_last_hour` | bytes the boards sent through the gate in those dials |

A refusal for `rate` or `busy` is the gate's own limit keeping a caller from a
board; `not_petscii` and `unknown` are a C64 at an ANSI board and a board gone
from the list.

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
(`dials_live`, `dials_*`, `dial_*`, see [Dialling](#dialling)), and `geoip_age_seconds`, `db_bytes`,
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
  ui/modern/own_servers.rb             the dialing menu of our own boards on an ANSI terminal
  ui/modern/discovery/                 Global Discovery: home, menus, lists, the board page, search, sources
  ui/petscii.rb                        the PETSCII face: the call, its node number, goodbye
  ui/petscii/gate.rb                   one C64 call: the frame, the tabs, the sub-menu focus, the keys, dialling, find
  ui/petscii/chrome.rb                 the header, the tabs, the sub-menu and the hint bar
  ui/petscii/layout.rb                 the 40×25 grid of the frame and the drawing helpers
  ui/petscii/diff.rb                   the changed cells as PETSCII, row by row
  ui/petscii/views/                    Own Servers, a list of boards, a menu, a board's page, Sources, text pages
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
`/srv/stacks/ttg-gate-bbs`. The image runs the rubbs revision of `Gemfile.lock`, as uid 1000.

## License

MIT, © 2026 Teletype Games.
