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
| `FEEDIA_BBS_DB` | `data/feedia.sqlite3` | The board's SQLite database: the admins' inbox of before the network's feedback (compose mounts `./data`) |
| `TTG_CENTRAL_URL` | `http://ttg-gate-bbs:8090` | The network's Central (TTG Gate BBS), where feedback and the wall live |
| `RUBBS_AUTH_SECRET` | — | The secret every board of the network shares (in `.env` on the server) |

## Interface

A call starts with one question: which terminal is calling. It is rubbs'
`Rubbs::Common::Call::Terminal`: the board guesses from the telnet answers (wider than 40
columns is a modern terminal; 40 columns or no answer is a Commodore), `1` (or
`M`) picks the modern face, `2` (or `C`) the C64, and RETURN takes the pick or
the guess.

A feed is fetched when it is opened (rubbs' `Rubbs::Common::Web::HTTP`: public addresses
only, http(s) redirects only, at most 1 MB) and kept for 10 minutes
(`Rubbs::Common::Storage::Cache`): callers opening the same feed at once share one fetch. Up to 60
items of it are shown. The item's HTML becomes plain text: paragraphs, headings, lists
and quotes are kept, a link keeps its text with a number (`Comments[1]`) and
its address is listed under the text, an image keeps its alt text. Control
characters are dropped (`Rubbs::Common::Text.clean`, the item's address too), so a feed
cannot send escape sequences to the terminal. Most feeds carry only a summary: the item's own address is under it.

### The modern face

A desktop under a menubar, the feed list open on it: the feeds on the left,
the one picked on the right. Enter opens a feed in a window of its own: the
items on the left, the text of the one picked on the right, its address under
it. `QR code` shows the item's address as a QR code (rubbs' `Rubbs::Common::Text::QR`, half
blocks) to read with a phone; `Reload` fetches the feed again, past the cache.
The code takes the room the screen has: on 80×24 an address of up to about 55
characters fits, on a taller screen a longer one; one that does not fit gets a
message, and the address stays under the text.

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
lists are cursor menus of rubbs (`Rubbs::Common::Screens::Selector`): CRSR moves the bar, RETURN
takes the lit item, and the letters (or the number typed, in a list) work as
well; CRSR left and right turn the pages of a list, `Q` or `←` (RUN/STOP too)
goes back. An item stops at every screenful. Every line is typed in a field of
rubbs (`Rubbs::Common::Screens::Field`: the cursor keys move in it, DEL deletes, RETURN ends it,
RUN/STOP or `←` goes back), the feedback in its full-screen editor
(`Rubbs::Common::Screens::Editor`): RUN/STOP or `←`, then `S` sends it. Accented letters come as their
nearest ASCII (the PETSCII line of rubbs).

Under the last page of an item with an address, `C` (qr code) shows the
address as a QR code (rubbs' `Rubbs::Common::Text::QR`, quadrant blocks, up to about 100
characters) in the middle of the screen, for a phone to open what the C64
cannot.

## The editors' box and the wall

What callers send the editors is the network's feedback (ttg-common `TTG::Feedback`, kept on TTG Gate
BBS): **Suggest a feed** (the `feed` kind: the address, its name, why) and **Something else**, in the
words of `lib/content/feedback.yml`. The sysops read it on the gate's console (SysOp › FEEDBACK); Discord
only hears that something came. Feedia never fetches a suggested address itself: an editor looks at it
and, if it stays, adds it to `config/feeds.yml`.

The **Wall** (ttg-common `TTG::Wall`, `lib/content/wall.yml`) is where readers talk about the news.

The board's own inbox of before (the `messages` table in `data/feedia.sqlite3`) is handed over to the
network's feedback once, by a background job (`inbox export`), and kept here marked (`exported_at`);
`docker exec feedia-bbs bin/inbox-export` does it at once and says what is left.

## Project structure

```
bbs.rb                          entry point: the board, the terminal question, then a face
bin/inbox-export                hands the inbox of before over to the network's feedback now
rake test                        the domain's tests (minitest, no network)
config/feeds.yml                the feed list
lib/
  domain.rb                     requires the domain in dependency order
  domain/
    feedia_bbs.rb               FeediaBBS, the composition root: reads ENV, wires the rest
    migrations.rb               the schema of the database, one step per version
    model/feed_model.rb         one feed of the list
    model/channel_model.rb      what a feed said: title, link, description, items
    model/item_model.rb         one item: title, link, date, author, Markdown
    model/message_model.rb      the inbox of before (Rubbs::Common::Storage::Model), handed over to TTG::Feedback
    model/feed_xml.rb           RSS/RDF/Atom → a channel and its items
    model/html_text.rb          an item's HTML → Markdown, numbered links
    repository/feed_list_repository.rb  config/feeds.yml
    repository/feed_repository.rb       fetching a feed (Rubbs::Common::Web::HTTP), the cache (Rubbs::Common::Storage::Cache)
    service/feed_service.rb     the feed list, reading a feed
  ui/logo.rb                    FEEDIA in half blocks for the modern masthead
  ui/modern.rb                  the modern face: the Application from the parts below
  ui/modern/                    one module a window (feeds, channel),
                                the menubar, the masthead, the helpers
  ui/petscii.rb                 the PETSCII face: logo, menu, lists, pages
lib/content/                    feedback.yml and wall.yml: the board's words for ttg-common's screens
  ui/petscii/screen.rb          the 40×25 screen: rubbs' Rubbs::Petscii::Screen
test/                           the domain's tests
```

## Logs

Every line on stderr starts with the log tag `feedia-bbs:` (rubbs' `Rubbs.log`):
`feedia-bbs: feed: <name>: …` for a feed that did not answer or sent no feed,
`feedia-bbs: inbox export: …`. The repositories let a
failure go up; the services log it once and the faces say "did not answer".

## Tests

```bash
bundle exec rake test              # all of them
bundle exec rake test message      # the files whose name has the word
```

## Deploy

A push to master deploys from Woodpecker: RuboCop, the tests, a compose check, then
`ci-deploy feedia-bbs` on the server (infra/host-config), which runs the stack in
`/srv/stacks/feedia-bbs`; `data/` and `.env` stay. The image runs the rubbs revision of
`Gemfile.lock`, as uid 1000.
