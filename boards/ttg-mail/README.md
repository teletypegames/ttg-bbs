# TTG Mail BBS

Letters between the accounts of the Teletype Games BBS network, on a telnet line. Log in with
your account of the network, open your mailbox, write to anyone with an account, read and answer
your letters. A board of the network, powered by [rubbs](https://git.teletypegames.org/engines/rubbs)
and [ttg-common](https://git.teletypegames.org/bbs/ttg-bbs/src/branch/master/boards/common).

It has two faces on one port, like every board of the network:

- a **modern** one for ANSI terminals: the desktop is the **post office from the street**
  (`lib/content/art/post_office.yml`, a rubbs `Scene`): the clock in the sign, *Welcome, name* over the
  door, the red pillar box whose **flag goes up** and shows the count when there are new letters, a
  **pigeon** flying a letter across the night sky a step a second, and the street's line saying what
  is new; under it two columns, **Your post** (the newest letters, a ★ for a new one) and **On the
  wall** (the newest notes). A menubar: Mail (Mailbox F2, The wall F3, Write to the sysops F7), You
  (Profile); each screen on the whole line;
- a **Commodore 64** one in PETSCII, 40×25: **TTG MAIL** in reversed blocks, red going to white, over
  a line about the pillar box (*flag up! 2 new letters*), then a cursor menu — `M` mailbox, `W`
  the wall, `F` write to the sysops, `P` profile.

A letter is read on its **sheet**: a frame with the network's red stamp in the corner, the writer,
the reader and the day, the subject and the letter under a rule and the **TTG MAIL postmark** at the
bottom; a sent one runs into the pillar box in a little film (ttg-common 0.12
`TTG::PrivateMessage::Stationery`).

## The mailbox

The mailbox is ttg-common's `TTG::PrivateMessage` (the network's letters, kept on TTG Gate BBS, the
Central, as a service of rubbs' `Rubbs::Common::Central`):

- the letters to the caller, newest first, a new one marked; the sent letters on a list of their own;
- a letter taken is read whole (and so marked read), then answered (`Re:`), deleted, or its writer
  blocked (the writer's next letters are refused as if there were no such account);
- a new letter asks the account to write to, the subject on a line, and the letter in the
  full-screen editor (up to 4000 characters);
- accounts only: a guest is told to log in or make an account in the profile (the splash asks
  *Login | Register | Guest* too).

The Central keeps the limits (one letter in 30 seconds and 50 a day an account) and refuses a
letter to a banned account. The words of the screen are `lib/content/mail.yml` over ttg-common's
defaults. The status line (modern) and the menu (C64) show how many letters are new.

**The wall and feedback** are the network's too (ttg-common `TTG::Wall`, `TTG::Feedback`): the post
office wall (`lib/content/wall.yml`) and a word to the sysops, read on the sysops' feedback desk.

## Running

The board is `boards/ttg-mail` of [TTG BBS](https://git.teletypegames.org/bbs/ttg-bbs) and runs
with the other boards in one container. From the repository root:

```bash
docker compose up --build       # every board, this one on 2335
```

or directly (Ruby 3.3): `bundle install && bin/board ttg-mail` (on 2335, from `boards.yml`), or on
its own `cd boards/ttg-mail && BBS_PORT=2335 bundle exec ruby bbs.rb`; then `telnet localhost 2335`.
Every environment variable is in `env-example` with its default.

| Variable | Default | |
|---|---|---|
| `BBS_PORT` | `2323` | the port to listen on (in the container the supervisor sets 2335 from `boards.yml`) |
| `BBS_MAX_SESSIONS` | `100` | callers at once (`boards.yml` sets 50) |
| `TTG_CENTRAL_URL` | `http://ttg-gate-bbs:8090` | the network's Central (TTG Gate BBS) on the interstack network |
| `RUBBS_AUTH_SECRET` | — | the secret every board of the network shares, in `.env` on the server |

The board keeps no data of its own: without the Central it still answers, and says the mail cannot
be reached.

## Project structure

```
bbs.rb                         entry point: Rubbs.board (title, domain, preset, central, auth, faces)
lib/domain.rb                  requires the domain in dependency order
lib/domain/
  model/mailbox_summary_model.rb  a caller's mailbox at a glance: new letters, the Central reachable
  model/desk_model.rb          the post office's desk: the summary, the newest letters and notes
  service/mail_service.rb      the summary and the desk from the Central (TTG::PrivateMessage, TTG::Wall), kept 20 s
  ttg_mail_bbs.rb              the board's domain (TTGMailBBS, a Rubbs::Common::Board::Domain): no data of its own
lib/content/mail.yml           the board's words for ttg-common's mailbox
lib/content/wall.yml           the board's words for ttg-common's wall
lib/content/art/post_office.yml  the post office of the modern desktop (cp437, 256 colours, hotspots:
                               sky, clock, caller, flag, count, status)
lib/ui/
  modern.rb                    UI::Modern::APP: the rubbs Application, its desktop
  modern/post_office.rb        UI::Modern::PostOffice: the post office scene, filled from the desk
  modern/helpers.rb            the desk, the columns under it, the screens on the line
  petscii.rb                   UI::Petscii < Rubbs::Petscii::Face: the C64 board, the TTG MAIL lettering
test/                          the board's words load; the mailbox summary
```

## Deploy

A push to master of bbs/ttg-bbs deploys every board from Woodpecker: RuboCop, the tests and
`rake bbs:check`, a compose check, then `ci-deploy ttg-bbs` on the server, which runs the stack in
`/srv/stacks/ttg-bbs` (container `ttg-bbs`). A change only in `boards/ttg-mail` restarts only this
board. Its log lines are in `docker logs ttg-bbs`, with `"board":"ttg-mail-bbs"`.

## Licence

MIT, see the repository's `LICENSE`.
