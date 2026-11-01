# Feedia BBS

An RSS reader on a telnet line. Pick a feed from the list, and Feedia BBS fetches
it and shows its items in a form a terminal can read: the title, the date and
the author, the text wrapped to the screen, its links numbered under it.
Callers can suggest a new feed or send feedback to the admins. Built on the
[rubbs](https://git.teletypegames.org/engines/rubbs) gem, like the
[Teletype BBS](https://git.teletypegames.org/bbs/teletype-bbs) and
[Alexandria BBS](https://git.teletypegames.org/bbs/alexandria-bbs).

It has two faces on one port: the **modern** one for ANSI terminals (windows,
menus, mouse) and a **Commodore 64** one in PETSCII, 40×25, with single-key
menus.

## Running

**Docker Compose:**

```bash
docker compose up --build
```

**Directly (Ruby 3.x):**

```bash
bundle install
ruby bbs.rb
```

Connect:

```bash
telnet localhost 2327      # compose
telnet localhost 2323      # directly (BBS_PORT)
```

## Configuration

The feeds are listed in [`config/feeds.yml`](config/feeds.yml), in the order a
caller sees them:

```yaml
- name: Hacker News                         # required
  url: https://news.ycombinator.com/rss     # required, http(s)
  group: Tech                               # shown with it
  lang: en                                  # shown with it
  about: The front page of Hacker News.     # shown with it
```

A new feed is a commit to that file: a push to master deploys it. RSS
0.9x/2.0, RSS 1.0 (RDF) and Atom all work.

Copy `env-example` to `.env`:

| Variable | Default | Description |
|---|---|---|
| `BBS_PORT` | `2323` | TCP port to listen on (in the container; compose publishes it on 2327) |
| `BBS_MAX_SESSIONS` | `100` | Callers at once (compose sets 50) |
| `FEEDIA_BBS_FEEDS` | `config/feeds.yml` | The feed list |
| `FEEDIA_BBS_DB` | `data/feedia.sqlite3` | The board's SQLite database: suggestions and feedback (compose mounts `./data`) |
| `FEEDIA_BBS_DISCORD_WEBHOOK` | — | Suggestions and feedback ring this Discord webhook too |

## Interface

A call starts with one question: which terminal is calling. It is rubbs'
`BBS::Terminal`: the board guesses from the telnet answers (wider than 40
columns is a modern terminal; 40 columns or no answer is a Commodore), `1` (or
`M`) picks the modern face, `2` (or `C`) the C64, and RETURN takes the pick or
the guess.

A feed is fetched when it is opened (rubbs' `BBS::HTTP`: public addresses
only, http(s) redirects only, at most 1 MB) and kept for 10 minutes
(`BBS::Cache`): callers opening the same feed at once share one fetch. Up to 60
items of it are shown. The item's HTML becomes plain text: paragraphs, headings, lists
and quotes are kept, a link keeps its text with a number (`Comments[1]`) and
its address is listed under the text, an image keeps its alt text. Control
characters are dropped (`BBS::Text.clean`, the item's address too), so a feed
cannot send escape sequences to the terminal. Most feeds carry only a summary: the item's own address is under it.

### The modern face

A desktop under a menubar, the feed list open on it: the feeds on the left,
the one picked on the right. Enter opens a feed in a window of its own: the
items on the left, the text of the one picked on the right, its address under
it. `Reload` fetches the feed again, past the cache.

| Key | Action |
|---|---|
| `F2` | Feed list |
| `F7` | Suggest a feed… |
| `F8` | Send feedback… |
| `Enter` | Open the feed |
| `Alt-S` | Send (in the forms) |
| `F5` / `Alt-Enter` | Full screen and back |
| `F6` / `Shift-F6` | Next / previous window |
| `Esc` | Close the window |
| `F10` | Menu |
| `Alt-X` | Log off |

### The C64 face

The FEEDIA logo and a menu: `F` feeds, `S` suggest a feed, `W` write to the
admins, `Q` log off. Feeds and items are numbered lists. The menu and the
lists are cursor menus of rubbs (`BBS::Selector`): CRSR moves the bar, RETURN
takes the lit item, and the letters (or the number typed, in a list) work as
well; CRSR left and right turn the pages of a list, `Q` or `←` (RUN/STOP too)
goes back. An item stops at every screenful. Every line is typed in a field of
rubbs (`BBS::Field`: the cursor keys move in it, DEL deletes, RETURN ends it,
RUN/STOP or `←` goes back), the feedback in its full-screen editor
(`BBS::Editor`): RUN/STOP or `←`, then `S` sends it. Accented letters come as their
nearest ASCII (the PETSCII line of rubbs).

## The admins' inbox

A suggestion (the feed's address, its name, why, who) or a feedback (the text,
who) is a row of the `messages` table in `data/feedia.sqlite3`, and a message
on the Discord webhook when there is one (mentions off, links not unfurled).
The newest 1000 are kept. A caller (by IP address) can send five messages an
hour, all callers together thirty. The `data/inbox.jsonl` of earlier versions
is taken in on the first start and renamed `inbox.jsonl.imported`. Feedia
never fetches a suggested address itself: an admin looks at
it and, if it stays, adds it to `config/feeds.yml`. To read the inbox on the
server:

```bash
docker exec feedia-bbs bin/inbox        # the newest 20
docker exec feedia-bbs bin/inbox 100
```

## Project structure

```
bbs.rb                          entry point: the board, the terminal question, then a face
bin/inbox                       the admins' look at the inbox
bin/test                        the domain's tests (minitest, no network)
config/feeds.yml                the feed list
lib/
  domain.rb                     requires the domain in dependency order
  domain/
    feedia_bbs.rb               FeediaBBS, the composition root: reads ENV, wires the rest
    model/feed_model.rb         one feed of the list
    model/channel_model.rb      what a feed said: title, link, description, items
    model/item_model.rb         one item: title, link, date, author, Markdown
    model/message_model.rb      a suggestion or feedback to the admins
    model/feed_xml.rb           RSS/RDF/Atom → a channel and its items
    model/html_text.rb          an item's HTML → Markdown, numbered links
    repository/feed_list_repository.rb  config/feeds.yml
    repository/feed_repository.rb       fetching a feed (BBS::HTTP), the cache (BBS::Cache)
    repository/inbox_repository.rb      the messages table, the import of inbox.jsonl
    repository/discord_repository.rb    the admins' Discord webhook, rate-limited
    service/feed_service.rb     the feed list, reading a feed
    service/inbox_service.rb    suggestions and feedback: checks, limits, the inbox, Discord
  ui/logo.rb                    FEEDIA in half blocks for the modern masthead
  ui/modern.rb                  the modern face: the Application from the parts below
  ui/modern/                    one module a window (feeds, channel, suggest, feedback),
                                the menubar, the masthead, the helpers
  ui/petscii.rb                 the PETSCII face: logo, menu, lists, pages, messages
  ui/petscii/screen.rb          the 40×25 screen: rubbs' BBS::Petscii::Screen
test/                           the domain's tests
```

## Tests

```bash
bundle exec bin/test              # all of them
bundle exec bin/test inbox        # the files whose name has the word
```

## Deploy

A push to master deploys from Woodpecker: RuboCop, the tests, a compose check, then
`ci-deploy feedia-bbs` on the server (infra/host-config), which runs the stack in
`/srv/stacks/feedia-bbs`; `data/` and `.env` stay. The image runs the rubbs revision of
`Gemfile.lock`, as uid 1000.
