# frozen_string_literal: true

require 'bbs'
require_relative '../characters/ra'

# Chat of Ra: the caller is the worker sealed in the pyramid, and the sun
# god answers from above. Words go to the model (Ra's persona); RIDDLE asks
# one of the riddles of the pyramid, and three solved ones earn the
# blessing: the way out, to the game itself.
module Ra
  SUN = [
    '               \\   |   /',
    "             '.  \\  |  /  .'",
    '          -----  (  ☼  )  -----',
    "             .'  /  |  \\  '.",
    '               /    |    \\',
    '',
    '                    /\\',
    '                   /  \\',
    '                  / ▓▓ \\',
    '                 /______\\'
  ].freeze

  HELP = ['Speak, and Ra answers. RIDDLE: a riddle of the pyramid (HINT helps, SKIP gives it up).',
          'GAME: the game of this story. EXIT: back to the BBS.'].freeze

  def self.os(games:)
    BBS::FakeOS.define do
      name   'CHAT OF RA'
      prompt '☼ '
      colors text: "\e[0;33m", bright: "\e[1;33m", accent: "\e[1;33m",
             dim: "\e[0;37m", error: "\e[0;31m", prompt: "\e[1;33m"

      boot { Ra.boot(self) }
      Ra.riddle_commands(self)
      Ra.chat_commands(self, games)
    end
  end

  # The sun rising over the pyramid, the banner and the help.
  def self.boot(os)
    os.cls
    SUN.first(5).each { |line| os.print line, style: :bright, delay: 0.08 }
    SUN.drop(5).each { |line| os.print line, delay: 0.08 }
    os.newline
    os.big_banner 'Chat of Ra', font: 'small'
    os.type 'The stone is cold and the dark is old. Far above, the sun god listens.', style: :dim, cps: 60
    os.newline
    HELP.each { |line| os.puts line, style: :dim }
    os.newline
  end

  def self.riddle_commands(os)
    os.command 'riddle', help: 'a riddle of the pyramid' do |_args, io|
      riddle = (Ra::RIDDLES - [io.ctx[:ra_riddle]]).sample
      io.ctx[:ra_riddle] = riddle
      io.ctx[:ra_tries]  = 0
      io.newline
      Ra.speak(io, riddle['riddle'])
    end

    os.command 'hint' do |_args, io|
      riddle = io.ctx[:ra_riddle]
      Ra.speak(io, riddle ? riddle['hint'] : 'There is no riddle between us yet. Ask me for one: RIDDLE.')
    end

    os.command 'skip' do |_args, io|
      riddle = io.ctx.delete(:ra_riddle)
      Ra.speak(io, riddle ? "It was #{riddle['answers'].first}. Another time, little one." : 'There is nothing to give up.')
    end
  end

  # GAME, HELP, EXIT, and what is not a command: a guess at the riddle, or
  # words for Ra.
  def self.chat_commands(os, games)
    os.command('game') { |_args, io| io.newline; Ra.speak(io, Ra.game_line(games)) }
    os.command('help') { |_args, io| HELP.each { |line| io.puts line, style: :dim } }
    os.command('exit', 'quit', 'bye') { |_args, io| Ra.speak(io, 'Go with the light.'); io.halt }
    os.on_unknown { |input, io| io.ctx[:ra_riddle] ? Ra.guess(io, input, games) : Ra.talk(io, input, games) }
  end

  def self.talk(io, input, games)
    io.newline
    out = BBS::AI::Typewriter.new(io, prefix: 'RA: ', style: :bright)
    Ra.reply(input, io.ctx, games) { |piece| out.write(piece) }
    out.finish
  end

  def self.speak(io, text)
    out = BBS::AI::Typewriter.new(io, prefix: 'RA: ', style: :bright)
    out.write(text)
    out.finish
  end

  def self.guess(io, input, games)
    riddle = io.ctx[:ra_riddle]
    io.newline
    answer?(riddle, input) ? solved(io, riddle, games) : missed(io, riddle)
  end

  # A riddle solved: one blessing more, and at BLESSINGS the game.
  def self.solved(io, riddle, games)
    io.ctx.delete(:ra_riddle)
    blessings = io.ctx[:ra_blessings] = io.ctx.fetch(:ra_blessings, 0) + 1
    return praise(io, riddle, blessings) if blessings < BLESSINGS || io.ctx[:ra_blessed]

    io.ctx[:ra_blessed] = true
    speak(io, "Yes. That is #{blessings} riddles, and the blessing is yours: the walls open, and the light finds you.")
    speak(io, game_line(games))
  end

  def self.praise(io, riddle, blessings)
    speak(io, "Yes, little one: #{riddle['answers'].first}. " \
              "#{blessings < BLESSINGS ? "#{BLESSINGS - blessings} more, and I bless you." : 'The sun is pleased.'}")
  end

  # A wrong answer: the second earns the hint, the third gives it away.
  def self.missed(io, riddle)
    tries = io.ctx[:ra_tries] = io.ctx.fetch(:ra_tries, 0) + 1
    if tries >= 3
      io.ctx.delete(:ra_riddle)
      speak(io, "No. It was #{riddle['answers'].first}. Ask me again when you are ready: RIDDLE.")
    else
      speak(io, tries == 2 ? "No. #{riddle['hint']}" : 'No, little one. Think again.')
    end
  end
end
