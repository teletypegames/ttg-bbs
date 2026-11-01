# frozen_string_literal: true

# The doors of the board, in the order of the Doors menu; each label marks
# its hotkey with &.
module TeletypeDoors
  NAMES = ['SERMO', 'Commodore 64', 'Commodore Plus/4', 'Chat of Ra', 'TTG Trivia'].freeze

  def self.build(games:, sizes:, site:, scores:)
    [sermo, c64(games, sizes), plus4(games, sizes), ra(games), trivia(games, site, scores)]
  end

  def self.sermo
    DoorModel.new(name: :sermo, program: Sermo::OS, label: '&SERMO', cols: 80, tag: 'neumatronic machine',
                  hint: 'SERMO: a dual machine of the Neumatronic universe; type a command, or just talk to it',
                  about: 'The Margittai machine of the Neumatronic universe, running SERMO. Type its commands, ' \
                         'or talk to it: its Lapis-ACP answers. EXIT brings you back.')
  end

  def self.c64(games, sizes)
    DoorModel.new(name: :c64, program: Commodore.os(Commodore::C64, games: games, sizes: sizes),
                  label: '&Commodore 64', cols: 40, tag: 'c64 + our games',
                  hint: 'A Commodore 64 at READY., with our C64 games on its disk: LOAD"$",8 lists them',
                  about: 'A Commodore 64 at its READY. prompt, with a small BASIC V2. The disk holds our C64 games: ' \
                         'LOAD"$",8 and LIST show the directory, LOAD"NAME",8 and RUN show a game. EXIT returns.')
  end

  def self.plus4(games, sizes)
    DoorModel.new(name: :plus4, program: Commodore.os(Commodore::PLUS4, games: games, sizes: sizes),
                  label: 'Commodore &Plus/4', cols: 40, tag: 'plus/4 + our games',
                  hint: 'A Commodore Plus/4 with our Plus/4 games on its disk: DIRECTORY lists them',
                  about: 'The grey screen of the Plus/4 and its BASIC 3.5 habits: DIRECTORY and DLOAD work, and ' \
                         'the disk holds our Plus/4 games. EXIT returns.')
  end

  def self.ra(games)
    DoorModel.new(name: :ra, program: Ra.os(games: games), label: 'Chat of &Ra', cols: 80, tag: 'talk to the sun god',
                  hint: 'Talk to Ra in the pyramid of Blessing of Ra; solve three riddles for his blessing',
                  about: 'You are the worker sealed in the pyramid of Blessing of Ra, and the sun god answers from ' \
                         'above. RIDDLE asks one of the pyramid\'s riddles; three solved earn his blessing.')
  end

  def self.trivia(games, site, scores)
    DoorModel.new(name: :trivia, program: Trivia.door(games: games, site: site, scores: scores),
                  label: '&TTG Trivia', cols: 80, tag: 'quiz, high scores',
                  hint: 'Ten questions, 20 seconds each, A to D: quick answers and streaks score more',
                  about: 'A door game of the old kind: ten questions about our games, the team and old computers, ' \
                         '20 seconds each. A quick answer is worth more, three in a row earn a bonus, and the best ' \
                         'ten games are in the Hall of Fame.')
  end
end
