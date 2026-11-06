# TTG Mail BBS

Letters between the accounts of the Teletype Games BBS network, on a telnet line. Log in with
your account of the network, open your mailbox, write to anyone with an account, read and answer
your letters. A board of the network, powered by [rubbs](https://git.teletypegames.org/engines/rubbs)
and [ttg-common](https://git.teletypegames.org/bbs/common).

It has two faces on one port, like every board of the network:

- a **modern** one for ANSI terminals: the logo on the desktop, a menubar (Mail: Mailbox F2, The
  wall F3, Write to the sysops F7; You: Profile), and each screen on the whole line;
- a **Commodore 64** one in PETSCII, 40×25: a cursor menu — `M` mailbox, `W` the wall, `F` write
  to the sysops, `P` profile.

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

```bash
docker compose up --build
```

or directly (Ruby 3.3): `bundle install && BBS_PORT=2335 bundle exec ruby bbs.rb`, then
`telnet localhost 2335`. Every environment variable is in `env-example` with its default.

| Variable | Default | |
|---|---|---|
| `BBS_PORT` | `2323` | the port inside the container (compose publishes it on 2335) |
| `BBS_MAX_SESSIONS` | `100` | callers at once (compose sets 50) |
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
  service/mail_service.rb      the summary from the Central (ttg-common TTG::PrivateMessage)
  ttg_mail_bbs.rb              the board's domain (TTGMailBBS, a Rubbs::Common::Board::Domain): no data of its own
lib/content/mail.yml           the board's words for ttg-common's mailbox
lib/content/wall.yml           the board's words for ttg-common's wall
lib/ui/
  logo.rb                      MAIL in rubbs' Rubbs::Common::Text::BlockFont
  modern.rb                    UI::Modern::APP: the rubbs Application
  petscii.rb                   UI::Petscii < Rubbs::Petscii::Face: the C64 board
test/                          the board's words load; the mailbox summary
```

## Deploy

A push to master deploys from Woodpecker: RuboCop, the tests and `rake bbs:check`, a compose check,
then `ci-deploy ttg-mail-bbs` on the server (`devarea/procedures/bbs-server-creation.md`).

## Licence

MIT, see `LICENSE`.
