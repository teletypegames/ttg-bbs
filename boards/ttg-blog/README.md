# TTGBLOG

The Teletype Games blog on a telnet line. Readers browse the latest posts or
the posts of a category and read them paged; the editors log in from the same
menu and write, edit and delete posts. Built on the
[rubbs](https://git.teletypegames.org/engines/rubbs) gem, like the
[Teletype BBS](https://git.teletypegames.org/bbs/bbs-server),
[Alexandria BBS](https://git.teletypegames.org/bbs/alexandria) and
[Feedia](https://git.teletypegames.org/bbs/feedia).

It has two faces on one port, and both are line by line, with no windows: a
**modern** one for ANSI terminals (up to 80 columns, the caller's window
height) and a **Commodore 64** one in PETSCII, 40×25. The menus, the lists and
the full-screen editor are the same on both.

## Running

**Docker Compose:**

```bash
docker compose up --build
docker exec -it ttgblog bin/user add NAME    # the first editor
```

**Directly (Ruby 3.x):**

```bash
bundle install
bin/user add NAME
ruby bbs.rb
```

Connect:

```bash
telnet localhost 2328      # compose
telnet localhost 2323      # directly (BBS_PORT)
```

## Configuration

The categories are listed in [`config/categories.yml`](config/categories.yml),
in the order a caller sees them; a post names its category by `id`:

```yaml
- id: devlog                                 # required, stored with the post
  name: Devlog                               # required, shown
  about: How the games and the tools are made
```

A change is a commit to that file: a push to master deploys it. A new post
can only pick a listed category; a post whose category left the list keeps it
and shows its bare id.

| Variable | Default | Description |
|---|---|---|
| `BBS_PORT` | `2323` | TCP port to listen on (in the container; compose publishes it on 2328) |
| `TTGBLOG_DB` | `data/ttgblog.sqlite3` | The SQLite database (compose mounts `./data`) |
| `TTGBLOG_CATEGORIES` | `config/categories.yml` | The category list |

## Data

One SQLite file, two tables:

- `users` — the editors: `name` (unique, case does not matter) and a
  PBKDF2-SHA256 password digest.
- `posts` — `title`, `summary`, `body` (Markdown), `category` (an id from the
  config), `author_id`, `created_at`, `updated_at` (UTC, ISO 8601).

Readers need no account. The editors are managed from the server's shell:

```bash
docker exec -it ttgblog bin/user list
docker exec -it ttgblog bin/user add NAME       # asks the password twice
docker exec -it ttgblog bin/user passwd NAME
docker exec -it ttgblog bin/user remove NAME    # their posts stay, without an author
```

A logged-in editor can change their own password from the menu too. Three
wrong logins end the tries of a call; each costs a second.

## Interface

A call starts with rubbs' `BBS::Terminal` question: which terminal is calling.
Then the masthead and the menu:

| Key | Action |
|---|---|
| `L` | Latest posts, newest first |
| `C` | Categories, with their post counts, then that category's posts |
| `E` | Editor login |
| `W` | Write a post (logged in) |
| `P` | Change your password (logged in) |
| `O` | Log out (logged in) |
| `Q` | Log off |

Lists are numbered: the number and RETURN opens a post, RETURN alone turns the
page, `Q` or `←` (Esc, RUN/STOP) goes back. A post shows its title, category,
date, author, the date of its last change, the summary, then the body,
paged a screenful at a time. An editor gets `E` edit and `D` delete under it.

### Writing

A new post asks for its title, category, summary and body in turn, then shows
the draft: `T` title, `C` category, `S` summary, `B` body, `V` view (as a
reader will see it), `W` save, `Q` quit (asks before dropping changes). Editing
a post opens the same draft screen.

The title, the summary and the body are written in the full-screen editor of
rubbs (`BBS::Editor`), which starts from the current text: the cursor keys move
anywhere in it, typing inserts at the cursor, DEL deletes before it, and the
lines wrap as they are typed. The title and the summary are one line each
(RETURN saves them); the body is Markdown, RETURN starts a new line and an
empty line a new paragraph.

| Key | Action |
|---|---|
| cursor keys | Move; up and down keep the column |
| HOME / END | Start / end of the screen row |
| PgUp / PgDn | A screenful up / down (modern terminal) |
| RUN/STOP or `←` (Esc), then `S` | Save |
| RUN/STOP or `←` (Esc), then `Q` | Quit, keep the text as it was |
| F1 (Ctrl-S) | Save at once (the Ultimate Term keeps F1 for its help) |

## Project structure

```
bbs.rb                    entry point: the terminal question, then a face
bin/user                  the editors, from the server's shell
config/categories.yml     the categories
lib/
  domain/blog.rb          the SQLite database: editors, posts, passwords
  ui/modern.rb            the modern face: the caller's window, half-block masthead
  ui/petscii.rb           the PETSCII face: 40×25 PETSCII, reversed-space masthead
  ui/board.rb             one call: menu, lists, a post, login, the editor, goodbye
  ui/screen.rb            title bar, pages, numbered lists, single-key menus
```

## Deploy

A push to master deploys from Woodpecker: RuboCop, a compose check, then
`ci-deploy ttgblog` on the server (infra/host-config), which runs the stack in
`/srv/stacks/ttgblog`; `data/` and `.env` stay. The entrypoint updates rubbs on
start.
