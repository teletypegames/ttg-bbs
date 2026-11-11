# Monitor BBS

Grafana's dashboards on a telnet line, for the accounts of the Teletype Games BBS network that have
the **`grafana`** role, and for no one else. A board of the network, powered by
[rubbs](https://git.teletypegames.org/engines/rubbs) and
[ttg-common](https://git.teletypegames.org/bbs/ttg-bbs/src/branch/master/boards/common).

## How a caller gets here

- **Only from the profile on TTG Gate BBS.** An account with the `grafana` role finds
  **Monitor BBS** (`M`) in its profile on the gate, on either face; the gate dials the board and
  hands the caller on signed in. Nobody else sees the item. The board is on no list: not on the
  gate's list of our boards, not on bbsweb, not on the town map, and no badge counts it
  (`private: true` in `boards.yml`, `TTG::Badges.boards` leaves it out).
- **The port is not published.** The board listens on 2336 inside the `ttg-bbs` container only;
  the gate, in the same container, dials `127.0.0.1:2336` (`TTG_GATE_BBS_MONITOR_HOST`/`_PORT`).
- **The board checks again.** Every call logs in first (`auth login: :call, guests: false`; a call
  from the gate comes signed in), and a caller without the role is told so and the call ends.
- A sysop gives the role on the gate: Profile › SysOp › Accounts, `G` grant, `grafana`.

## What it shows

It knows nothing of our dashboards in particular: it reads whatever Grafana's token sees, through
Grafana's HTTP API, and draws each panel by what it is and what its data looks like.

- **Dashboards** (`/api/search`), grouped by folder, or by the word before the colon of the title
  (`VPS: Host` is under VPS); `/` finds by title, tag or group.
- **A dashboard** (`/api/dashboards/uid/…`): its rows, each panel with what it shows *now* in one
  line (a sparkline and the highest series, a stat's values in their colours, a table's size and
  first row, a log's newest line, the alerts firing), and the chosen panel drawn in full under the
  list on a tall enough terminal. Panels load behind the screen, a few at a time, and the dashboard
  refreshes itself as often as it says (at least every 60 s, at most every 15 s).
- **A panel** on the whole screen: lines over time on a grid of braille dots (half blocks on a C64)
  with the value axis, the times and the legend's figures; stats as tiles with sparklines; gauges,
  bar gauges, pies and bar charts as bars; tables with their column colours and value mappings;
  logs with their level colours; state timelines as coloured strips; the alert rules with their
  state; text panels as text. `S` shows one series at a time, `I` the description.
- **Variables** (`V`): query variables get their options from the data source (Prometheus and
  Loki label values, SQL, `query_result`), with their regex and sort; custom, interval, constant
  and text box variables too; All, several values, chained variables. They are put into the
  queries as Grafana's front end does (a regex alternation for PromQL/LogQL, quoted lists for SQL,
  `${var:format}`).
- **The time range** (`T`, `SHIFT-T`): the dashboard's own, then 5m … 30d.

Grafana's data model is read, not our dashboards: field config defaults and overrides (by name,
regex, type, query), units (bytes, rates, percentages, durations, dates, custom suffixes),
decimals, min/max, thresholds (absolute and percentage), value mappings (value, range, regex,
special), colour modes and the classic palette, the reducers of stats and legends, Prometheus's and
Loki's table format, a panel reusing another's results (`-- Dashboard --`), and the
transformations organize, sortBy, reduce, merge, joinByField, labelsToFields, extractFields,
convertFieldType, groupingToMatrix, filterFieldsByName, limit, renameByRegex, seriesToRows. A
panel type it does not know is drawn by the shape of its data (log lines, series over time, single
values, a table); a transformation it does not know is named under the panel.

It reads Grafana with a **service account's token of the Viewer role**: it can only see what a
viewer sees, and changes nothing.

## Faces

Both faces run the same pages (`lib/ui/pages`), drawn as lines of coloured runs (`UI::Paint`):
`UI::Modern` writes them as 256-colour ANSI, `UI::Petscii` on a 40×25 PETSCII canvas in the
lowercase set (the nearest C64 colours, half-block charts, the chosen row reversed).

## Running

The board is `boards/monitor` of [TTG BBS](https://git.teletypegames.org/bbs/ttg-bbs) and runs
with the other boards in one container (`bin/board monitor`, port 2336 from `boards.yml`).

| Variable | Default | |
|---|---|---|
| `BBS_PORT` | `2323` | the port to listen on (the supervisor sets 2336 from `boards.yml`) |
| `BBS_MAX_SESSIONS` | `100` | callers at once (`boards.yml` sets 10) |
| `MONITOR_BBS_GRAFANA_URL` | `http://grafana:3000` | Grafana on the interstack network |
| `MONITOR_BBS_GRAFANA_TOKEN` | — | a Grafana service account's token (Viewer), in `.env` on the server |
| `TTG_CENTRAL_URL` | `http://ttg-gate-bbs:8090` | the network's Central (the accounts and their roles) |
| `RUBBS_AUTH_SECRET` | — | the secret every board shares, in `.env` on the server |

At most 6 questions go to Grafana at once over every caller (`MonitorService::PARALLEL`); a
dashboard's list and JSON are kept 60 s, a panel's data 15 s, shared between callers.

## Project structure

```
bbs.rb                          Rubbs.board: login at the call, no guests, both faces
lib/domain/grafana/             Grafana's API and data model: client, time range, interpolator,
                                units, colours, field display, reducers, transformations,
                                tabulate (table format), data sources, query runner, variables
lib/domain/grafana/build/       a panel and its frames made a Visual: by type, else by shape
lib/domain/model/               dashboard, panel, section, entry; variable, option; frame, field;
                                the visuals (chart, values, table, logs, states, alerts, text)
lib/domain/service/             MonitorService: what the board asks Grafana, cached, at most 6 at once
lib/domain/monitor_bbs.rb       the domain (settings, the service, ROLE)
lib/ui/paint.rb                 runs of coloured text, fitting and wrapping
lib/ui/modern.rb, petscii.rb    the two faces' drawing
lib/ui/charts.rb                line charts on a dot grid, sparklines, bars
lib/ui/render.rb, summary.rb    a Visual in a box, and in one line
lib/ui/loader.rb                a dashboard's panels loaded behind the screen
lib/ui/pages/                   Home (dashboards), Board (a dashboard), PanelPage, VariablesPage
lib/ui/monitor.rb               the way in: the role check, then the pages
```
