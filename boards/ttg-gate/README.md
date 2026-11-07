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
[Global Discovery](#global-discovery)). And it tells what kind of day it is: the
**Today** tab, the gate's daily page (see [Today](#today)).

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
  rest of the row (`BBS`, the node number: the C64 callers on the gate now, and
  the clock) in one colour, light grey;
- **row 1**, the two tabs, `OWN SERVERS` and `GLOBAL DISCOVERY`, in one colour,
  cyan: the active one a reversed band, the other plain, and on the right the
  boards online now (`O` and `D` switch them);
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
| O / D or G | the tab Own Servers / Global Discovery (it opens Browse), from anywhere |
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
`UI::Petscii::Canvas` (rubbs' `Rubbs::Petscii::Canvas`) and only the cells that
differ from what the C64 shows go out, row by row (`UI::Petscii::Diff`), or the
whole screen when that is shorter: a first screen is 0.95-1.15 KB, a step in a
list 200-360 bytes, the focus moving between the sub-menu and a list about 150.
While the caller thinks only the clock changes, once a minute; the call still
ends after the session's idle time. Before the line goes to a board the gate
switches back to the lowercase set, and the whole screen comes back, at the
same place, when the board hangs up.

## Running

The board is `boards/ttg-gate` of [TTG BBS](https://git.teletypegames.org/bbs/ttg-bbs) and runs
with the other boards in one container. From the repository root:

**Docker Compose** (every board, this one on 2399, and the prober):

```bash
docker compose up --build
```

**Directly (Ruby 3.x):**

```bash
bundle install
TTG_GATE_BBS_GATEWAY_HOST=teletypegames.org bin/board ttg-gate     # on 2399 (boards.yml)
cd boards/ttg-gate && TTG_GATE_BBS_GATEWAY_HOST=teletypegames.org bundle exec ruby bbs.rb   # on BBS_PORT or 2323
```

Connect:

```bash
telnet localhost 2399      # compose, bin/board
telnet localhost 2323      # bbs.rb on its own (BBS_PORT)
```

## Configuration

| Variable | Default | |
|---|---|---|
| `TTG_GATE_BBS_GATEWAY_HOST` | `host.docker.internal` | where the boards are dialled; the root `compose.yaml` maps it to the host |
| `TTG_GATE_BBS_PUBLIC_HOST` | `teletypegames.org` | the address shown with every board |
| `TTG_GATE_BBS_BOARDS` | `config/boards.yml` | the boards list |
| `TTG_GATE_BBS_OPS_WEBHOOK` | empty | Discovery: where import alerts go (an ops alert; the older `TTG_GATE_BBS_DISCORD_WEBHOOK` is still read); empty: off |
| `TTG_GATE_BBS_FEEDBACK_WEBHOOK` | empty | The network's feedback (ttg-common `TTG::Feedback`): the Discord line that something came, never what it says; empty: off |
| `TTG_GATE_BBS_DIAL_WINDOW` | `600` | Discovery: the window of the per-caller dial limit, seconds |
| `TTG_GATE_BBS_DIAL_PER_CALLER` | `10` | Discovery: the dials one caller may make in the window |
| `TTG_GATE_BBS_DIAL_PER_HOST` | `3` | Discovery: the lines from the gate to one address at once |
| `TTG_GATE_BBS_DIAL_IDLE` | `600` | Discovery: the seconds a relayed line may stay silent both ways |
| `TTG_GATE_BBS_DATA` | `data` | Discovery: the data folder |
| `TTG_GATE_BBS_DISCOVERY_DB` | `data/discovery.sqlite3` | Discovery: the catalog |
| `TTG_GATE_BBS_DISCOVERY_OPTOUT` | `config/discovery-optout.yml` | Discovery: the opt-out list |
| `BBS_PORT` | `2323` | the port to listen on (rubbs); in the container the supervisor sets 2399 from `boards.yml` |
| `BBS_MAX_SESSIONS` | `50` | callers at once (rubbs; `boards.yml` sets it in the container) |

`env-example` lists them all. In Docker the root `compose.yaml` sets the ones that differ (the
webhooks and the secret from the stack's `.env`).

Every log line starts with the process's tag (rubbs' `Rubbs.log`, `log_tag`):
`ttg-gate-bbs:` for the gate, `ttg-gate-bbs-prober:` for the prober and the
import, which run in the prober's container; then what it is about (`dial`,
`probe`, `import`, `geoip`, `metrics` …). The gate's lines are in `docker logs ttg-bbs`, with
`"board":"ttg-gate-bbs"`; the prober's in `docker logs ttg-gate-bbs-prober`. Our own boards are
on the host (`host.docker.internal`, a private address), so the gateway to them is the one
that may call a non-public address (`public_only: false`); a board of the
catalog is dialled by its vetted public address only.

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

**Modern:** under the logo the tabs, **Own Servers** | **Global Discovery** |
**Today** | **Profile**; TAB or the right arrow goes to the next, the left arrow back, and
each keeps its place. The profile takes the screen; from it the caller comes back
to the tab they left. On Own Servers the arrows choose a board, RETURN or its
number dials it, `T` opens Today, `Q` or Esc hangs up. Over the list one line
tells the day (the date, the name days, Budapest's weather). The rows show the board's colour bar,
name, tags and port; the description and the full address of the chosen one are
under the list. Global Discovery is described [below](#the-gate-ui).

**Commodore 64:** the frame and the tabs ([above](#the-c64-face)); CRSR up
from the top of the list reaches the tabs (on Global Discovery through its
sub-menu), where CRSR left and right switch OWN, GLOBAL and TODAY as the cursor goes and
RETURN opens YOU (the profile; `Y` or `P`); CRSR down goes back to the list. `D`
turns to Global Discovery (Browse: All, All PETSCII, All ASCII and the axes), `O` back to our own boards, the number dials, `Q`
hangs up.

Either way the board asks its own terminal question first: the gate reports the
caller's window size to it, so a modern terminal is its default, and a C64,
which has none, is taken for a C64.

## Today

The gate's daily page, a tab on both faces (`T`), after `docs/bbs/DAILY_HERALD.md`:

- **the day:** the date, day of the year and week, the Hungarian name days
  (`config/herald/namedays.yml`; in a leap year February 24 has none and the
  names of the 24th-28th come a day later), the holidays
  (`config/herald/holidays.yml`, the Easter ones worked out), sunrise, sunset and
  the moon (worked out, Budapest's time);
- **the weather** now, today and tomorrow in Budapest and, beside it, in the
  capital of the caller's country (the GeoIP of Global Discovery,
  `config/herald/capitals.yml`; the address is not kept), from Open-Meteo
  (CC BY 4.0);
- **the forint:** EUR, USD, GBP, CHF from the ECB's daily reference rates;
- **on this day** in history, from the English Wikipedia's feed (CC BY-SA);
- **earthquakes** of magnitude 4.5 and over in the last day, from the USGS;
- **the network:** the callers on the gate, our boards, the catalog's boards
  online and new this week, the board of the day (an online PETSCII board, the
  same one all day; RETURN opens its page) and the newest note of the walls.

A caller never waits for the web: a background job (`herald`, every ten minutes,
each source by its own pace) fetches what is due into `data/herald.sqlite3`, and
the page is made from it. A source that fails keeps its old payload until it is
too old to show; then its part is left out. `TTG_GATE_BBS_HERALD_FETCH=false`
stops the fetching. On the modern face the page has two columns and the network
under them; on a C64 it has four pages (`+`/`-`): TODAY, THE WORLD, ON THIS DAY,
THE NETWORK.

## Accounts and the sysop's console

The gate is the network's **Central** (rubbs `Rubbs::Common::Central`, `central serve:` in `bbs.rb`):
the accounts of the network live here (`data/accounts.sqlite3`, rubbs `Rubbs::Common::Auth`),
and the other boards ask them, with any other service of the network, on the `interstack`
network (`http://ttg-gate-bbs:8090`, `/auth` for the accounts, every request signed with
`RUBBS_AUTH_SECRET`; `TTG_GATE_BBS_CENTRAL_PORT`, 0 turns it off), and a
caller signed in here is signed in on the board the gate dials. The **PROFILE**
tab (**YOU** on a C64; or `P`) opens the caller's profile (log in, make an account, change the
password).

**Feedback and the walls.** The gate keeps the feedback, the walls and the letters of the network too
(ttg-common `TTG::Feedback`, `TTG::Wall`, `TTG::PrivateMessage`, services of the Central:
`data/feedback.sqlite3`, `data/wall.sqlite3`, `data/messages.sqlite3`). On the gate `W` (on Own Servers
or Today; there is no Wall tab) shows every board's wall together, newest first, and a caller writes on the
gate's own; **FEEDBACK** (`F`) is the gate's feedback box. On a C64 both are in the profile.

A caller with the `sysop` role finds **SysOp** in the profile, on either face:
the **console**. It is the gate's own (`lib/ui/sysop.rb`, `lib/ui/modern/sysop/`,
`lib/ui/petscii/sysop/`); rubbs only lends the place in the profile's menu
(`Rubbs::Common::Auth::Profile.extra`).

It looks and moves like the gate itself (both are rubbs' kit, `Rubbs::Petscii::Kit` and `Rubbs::Modern::Kit`): three
tabs, **CALLS**, **ACCOUNTS**, **FEEDBACK**, **WALL** and **LOG**, a row an item with the chosen one's
details under the list, and the steps on the list.

- **Calls:** who is on the gate now (an account or a guest), their address,
  how long, and under the list where the call came from (`telnet`,
  `bbs-web`), the face and where they are (`› Feedia BBS` while the gate
  carries them there). Redrawn every two seconds; RETURN or `H` hangs the
  chosen call up.
- **Accounts:** every account of the network with its roles and last login, a
  ✖ (a red `*` on a C64) for a banned one, the chosen one's roles, dates, calls
  on the gate and ban under the list; `/` finds names and roles (`blogger`
  lists the bloggers). `G` grants a role, `R` revokes one, `B` bans the account
  (with a reason; its calls on the gate are hung up) or lifts the ban, `N` gives
  it a new random password to pass on, `H` hangs up its calls. A banned
  account's right password gets *This account is closed.* on every board. A
  sysop cannot ban themselves or take their own sysop role.
- **Feedback:** what callers sent from every board (ttg-common `TTG::Feedback`), newest first: a dot for
  a new one, the board, the kind, who, the subject, and the chosen one's context, link and message
  under the list. RETURN reads it whole (and marks it read), `D` marks it done, `S` spam, `U` new
  again, `X` deletes it. Discord only says that something came.
- **Wall:** the notes of every board's wall, hidden ones too (✖, an `x` on a C64): `H` hides the
  chosen note or shows it again, `B` bars a guest's line from the walls for a day (an account is
  banned on ACCOUNTS).
- **Log:** the gate's last 500 log lines, the newest at the bottom (logins,
  wrong passwords, bans, dials, errors); `F` keeps the warnings and errors, `/`
  the lines with a word.

On a modern terminal TAB and the arrows go round the tabs, `Q` goes back to the
profile; on a C64 CRSR up reaches the tabs (`C`, `A`, `F`, `W`, `L` open them from
anywhere), `←` or RUN/STOP goes back.

Every step of the console is a log line with the sysop's name (`sysop: hung up
by=…`, `auth: ban … by=…`). Only the gate's own calls are listed: a caller who
dialled another board directly is that board's.

`bin/account` does the same from the server's shell, for the first sysop and the
import:

```sh
docker exec -it -w /app/boards/ttg-gate ttg-bbs bin/account password NAME     # sets it, makes the account when there is none
docker exec -it -w /app/boards/ttg-gate ttg-bbs bin/account grant NAME sysop
docker exec -it -w /app/boards/ttg-gate ttg-bbs bin/account ban NAME [REASON]
docker exec -it -w /app/boards/ttg-gate ttg-bbs bin/account unban NAME
docker exec -it -w /app/boards/ttg-gate ttg-bbs bin/account list
```

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
| [SyncTERM BBS list](https://synchro.net/syncterm.lst) | SyncTERM ini (the SBL export) | 243 | SyncTERM BBS list, synchro.net |
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

Every list is downloaded over https through `Rubbs::Common::Web::HTTP` (at most 32 MB, five
redirects, each to an http or https host on the public internet only) into a
temporary file, not the memory (`to:`); from a zip only its directory and the
member are read, and the member is inflated 64 KB at a time and stops at 16 MB;
the DB-IP file is inflated line by line from its file, and every text field is
cleaned of control and bidi characters (`Rubbs::Common::Text.clean`) before it is stored,
so a list cannot point the importer at the Docker network, fill the prober's
memory, or draw on a caller's screen.

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
and posts an alert to Discord (`TTG_GATE_BBS_OPS_WEBHOOK`).

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
C64 face on Browse. `ALL PETSCII` and `ALL ASCII` (the first lists of Browse, after
`All`) show every PETSCII, or every plain ASCII, board in
every state, online and flaky first, then down, not called and dead, then by
name, ten a page. The row under the title shows the
filter as chips (`PETSCII`, and the state: `All`, or what `F` chose), a dark
grey header (`Nr S Name CC Software`), then a board a row: its number, its state
mark (a half block: light green online, yellow flaky, red down, grey dead, dark
grey not called yet), its name, its country and its software; the
lit one a light blue bar. Under a rule the lit board's name, host and port,
state with the latency of the last answer and the country, software and
terminals, and the legend of the marks. `All` (Browse) lists every board of
the catalog, every encoding (chip `Any`): a board the C64 cannot call (neither
PETSCII nor plain ASCII) has a dark grey name, its encoding (`ANSI`, `ASCII`)
in the software column, and its page says so. An ASCII board without PETSCII is
white and dials: its page says `ASCII, translated` (see the dial rules). On the other lists only PETSCII boards are shown
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

- **Only the public internet.** The board's name is resolved once; every
  address must be public (`Rubbs::Common::Line::Address.public?`: no private, loopback,
  link-local, CGNAT, documentation, multicast or reserved range) and the port no
  well-known port of another service (`Address::SERVICE_PORTS`). The line goes
  to that address, never to the name again.
- **10 dials in 10 minutes a caller.** A caller is its IP address, an IPv6 one
  its /64; a line from a private address (bbsweb carries all its callers from
  the same host) counts by its connection.
- **3 lines to one address at once** from the gate: the address the board's
  name resolved to, so two listed names of one machine share them.
- **A silent line ends** after 600 seconds with no byte either way.
- The limits are the defaults of `TTG_GATE_BBS_DIAL_WINDOW`,
  `TTG_GATE_BBS_DIAL_PER_CALLER`, `TTG_GATE_BBS_DIAL_PER_HOST` and
  `TTG_GATE_BBS_DIAL_IDLE` (a value that is not a positive number keeps the
  default, with a warning).
- On the modern face a board made for a C64 only (PETSCII and no other
  encoding seen) asks first: it would be noise there. The C64 face dials
  PETSCII boards as they are, and plain ASCII ones (the `ascii` tag, no
  `petscii`) through rubbs' translation (`Rubbs::Common::Line::Gateway` `translate:`, an
  `AsciiBridge`): the board's text comes down as PETSCII in the C64's letter
  case, ANSI colours as C64 colours, CP437 line drawing as PETSCII glyphs, and
  the C64's keys go up as an ANSI terminal's; the board sees an `ANSI` terminal
  of 40 columns. An ANSI-only board stays refused on the C64. A dead board asks
  first too, on either face.
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
| `dial_limit{kind}` | the limits: `window_seconds`, `per_caller`, `per_host`, `idle_seconds` (a silent line ends) |
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

In `boards/ttg-gate`:

```bash
bin/discovery-import            # fetch every list into data/discovery.sqlite3
bin/discovery-report            # boards a source and their overlap, states, PETSCII measured vs claimed, tags
bin/discovery-prober --limit 20 # 20 calls, then stop (without --limit: a daemon)
rake test              # the tests (minitest, no network)
```

On the server the prober runs as the `ttg-gate-bbs-prober` service of the root
`compose.yaml` (the `ttg-bbs` image, working in `/app/boards/ttg-gate`; 128 MB, half a CPU, no
port); the import runs daily in its
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
bin/account                            the accounts from the server's shell (password, roles, bans, import)
bin/discovery-import                   Discovery: the daily import of the source lists
bin/discovery-prober                   Discovery: the prober daemon
bin/discovery-report                   Discovery: the catalog in numbers
rake test                              the tests (test/: the console on both faces; test/discovery/: Discovery)
config/boards.yml                      the boards of the menu
config/discovery/                      Discovery: sources, software signatures, source-to-tag rules
config/discovery-optout.yml            Discovery: the sysops who asked to be left out
config/herald/                         Today: the name days, the holidays, the capitals of the weather
lib/
  domain.rb                            requires the domain
  domain/migrations.rb                 the schemas: DISCOVERY_MIGRATIONS (the catalog), GEOIP_MIGRATIONS, HERALD_MIGRATIONS
  domain/model/board_model.rb          one board of the list
  domain/model/herald_model.rb         a row of the Today tab's cache
  domain/herald.rb, domain/herald/     Today: the calendar, the moon, the sources, the cache, the edition of a caller
  domain/repository/board_repository.rb  config/boards.yml, read once
  domain/service/directory_service.rb  the boards a caller can dial
  domain/ttg_gate_bbs.rb               the composition root (TTGGateBBS)
  ui/modern.rb                         the modern face: Own Servers | Global Discovery
  ui/modern/style.rb                   the gate's look on rubbs' Rubbs::Modern::Kit: the logo, the tabs, the state marks
  ui/modern/own_servers.rb             the dialing menu of our own boards on an ANSI terminal
  ui/modern/today.rb                   the Today tab on an ANSI terminal
  ui/today.rb                          what answers a caller's Today page, on either face
  ui/modern/discovery/                 Global Discovery: home, menus, lists, the board page, search, sources
  ui/sysop.rb                          the sysop's console: its place in the profile, the steps both faces share
  ui/modern/sysop/                     the console on a modern terminal: its tabs, calls, accounts, the log
  ui/petscii/sysop/                    the console on a C64: its frame, calls, accounts, the log
  ui/petscii.rb                        the PETSCII face: the call, its node number, goodbye
  ui/petscii/gate.rb                   one C64 call: rubbs' Rubbs::Petscii::Kit::Frame with the gate's places
  ui/petscii/gate/                     its places (Places), its calls (Dialing) and its find line (Input)
  ui/petscii/chrome.rb                 the gate's Rubbs::Petscii::Kit::Chrome: the tabs, the sub-menu, the hotkeys
  ui/petscii/layout.rb                 Canvas and Layout of rubbs' kit (the 40×25 grid and its drawing helpers)
  ui/petscii/views/                    Own Servers, a list of boards, a menu, a board's page, Sources, Today, text pages
  ui/colors.rb                         a board's accent on either face
  ui/dial.rb                           hands the line to a board (Rubbs::Common::Line::Gateway), by the dial rules for the catalog
  domain/discovery.rb                  requires Global Discovery
  domain/discovery/root.rb             its composition root (Discovery::Root)
  domain/discovery/model/              a Rubbs::Common::Storage::Model a table of the catalog (boards, sources, board_sources, probes,
                                       board_state, tags, boards_fts, meta, dials, dial_refusals) and of the DB-IP file,
                                       their queries; a source record, a probe result, a listing, a board page, a search
  domain/discovery/parser/             one parser a list format
  domain/discovery/repository/         the config, the opt-outs, HTTP, zip, the DB-IP file
  domain/discovery/service/            import, prober, probe recorder, telnet probe, state rules, banner rules, tags, report;
                                       the gate's browse, banner preview and dial rules
```

## Deploy

A push to master of bbs/ttg-bbs deploys every board from Woodpecker: RuboCop (this folder by its
own `.rubocop.yml`), the tests, a compose check, then `ci-deploy ttg-bbs` on the server
(infra/host-config), which runs the stack in `/srv/stacks/ttg-bbs`: the gate in the `ttg-bbs`
container, the prober in `ttg-gate-bbs-prober`. A change only in `boards/ttg-gate` restarts only
the gate; its data stays in `/srv/stacks/ttg-bbs/boards/ttg-gate/data`. The image runs the rubbs
revision of the root `Gemfile.lock`, as uid 1000.

## License

MIT, © 2026 Teletype Games.
