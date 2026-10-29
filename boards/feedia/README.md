# Feedia

An RSS reader on a telnet line. Pick a feed from the list, and Feedia fetches
it and shows its items in a form a terminal can read: the title, the date and
the author, the text wrapped to the screen, its links numbered under it.
Callers can suggest a new feed or send feedback to the admins. Built on the
[rubbs](https://git.teletypegames.org/engines/rubbs) gem, like the
[Teletype BBS](https://git.teletypegames.org/bbs/bbs-server) and
[Alexandria BBS](https://git.teletypegames.org/bbs/alexandria).

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
| `FEEDIA_FEEDS` | `config/feeds.yml` | The feed list |
| `FEEDIA_INBOX` | `data/inbox.jsonl` | Where suggestions and feedback are kept (compose mounts `./data`) |
| `FEEDIA_DISCORD_WEBHOOK` | — | Suggestions and feedback ring this Discord webhook too |

## Interface

A call starts with one question: which terminal is calling. It is rubbs'
`BBS::Terminal`: the board guesses from the telnet answers (wider than 40
columns is a modern terminal; 40 columns or no answer is a Commodore), `1` (or
`M`) picks the modern face, `2` (or `C`) the C64, and RETURN takes the pick or
the guess.

A feed is fetched when it is opened and kept for 10 minutes; up to 60 items of
it are shown. The item's HTML becomes plain text: paragraphs, headings, lists
and quotes are kept, a link keeps its text with a number (`Comments[1]`) and
its address is listed under the text, an image keeps its alt text. Control
characters are dropped, so a feed cannot send escape sequences to the
terminal. Most feeds carry only a summary: the item's own address is under it.

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
admins, `Q` log off. Feeds and items are numbered lists: the number and
RETURN opens one, RETURN alone turns the page, `Q` or `←` (RUN/STOP too) goes
back. An item stops at every screenful. The feedback is typed line by line, up
to ten; RETURN on an empty line sends it. Accented letters come as their
nearest ASCII (the PETSCII line of rubbs).

## The admins' inbox

A suggestion (the feed's address, its name, why, who) or a feedback (the text,
who) is one JSON line in `data/inbox.jsonl`, and a message on the Discord
webhook when there is one (mentions off, links not unfurled). One call can
send five. Feedia never fetches a suggested address itself: an admin looks at
it and, if it stays, adds it to `config/feeds.yml`. To read the inbox on the
server:

```bash
docker exec feedia bin/inbox        # the newest 20
docker exec feedia bin/inbox 100
```

## Project structure

```
bbs.rb                    entry point: the terminal question, then a face
bin/inbox                 the admins' look at the inbox
config/feeds.yml          the feed list
lib/
  domain/feeds.rb         the feed list; fetch, RSS/RDF/Atom → items, cache
  domain/html_text.rb     an item's HTML → Markdown, numbered links
  domain/inbox.rb         suggestions and feedback: the inbox file, Discord
  ui/modern.rb            the modern face: desktop, feeds, items, forms
  ui/petscii.rb           the PETSCII face: logo, menu, lists, pages, messages
  ui/petscii/screen.rb    title bar, pages, numbered lists on the 40×25 screen
```

## Deploy

A push to master deploys from Woodpecker: RuboCop, a compose check, then
`ci-deploy feedia` on the server (infra/host-config), which runs the stack in
`/srv/stacks/feedia`; `data/` and `.env` stay. The entrypoint updates rubbs on
start.
