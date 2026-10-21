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

      boot do
        cls
        SUN.first(5).each { |line| print line, style: :bright, delay: 0.08 }
        SUN.drop(5).each { |line| print line, delay: 0.08 }
        newline
        big_banner 'Chat of Ra', font: 'small'
        type 'The stone is cold and the dark is old. Far above, the sun god listens.', style: :dim, cps: 60
        newline
        HELP.each { |line| puts line, style: :dim }
        newline
      end

      command 'riddle', help: 'a riddle of the pyramid' do |_args, io|
        riddle = (Ra::RIDDLES - [io.ctx[:ra_riddle]]).sample
        io.ctx[:ra_riddle] = riddle
        io.ctx[:ra_tries]  = 0
        io.newline
        Ra.speak(io, riddle['riddle'])
      end

      command 'hint' do |_args, io|
        riddle = io.ctx[:ra_riddle]
        Ra.speak(io, riddle ? riddle['hint'] : 'There is no riddle between us yet. Ask me for one: RIDDLE.')
      end

      command 'skip' do |_args, io|
        riddle = io.ctx.delete(:ra_riddle)
        Ra.speak(io, riddle ? "It was #{riddle['answers'].first}. Another time, little one." : 'There is nothing to give up.')
      end

      command 'game' do |_args, io|
        io.newline
        Ra.speak(io, Ra.game_line(games))
      end

      command 'help' do |_args, io|
        HELP.each { |line| io.puts line, style: :dim }
      end

      command 'exit', 'quit', 'bye' do |_args, io|
        Ra.speak(io, 'Go with the light.')
        io.halt
      end

      on_unknown do |input, io|
        if io.ctx[:ra_riddle]
          Ra.guess(io, input, games)
        else
          io.newline
          out = BBS::AI::Typewriter.new(io, prefix: 'RA: ', style: :bright)
          Ra.reply(input, io.ctx, games) { |piece| out.write(piece) }
          out.finish
        end
      end
    end
  end

  def self.speak(io, text)
    out = BBS::AI::Typewriter.new(io, prefix: 'RA: ', style: :bright)
    out.write(text)
    out.finish
  end

  def self.guess(io, input, games)
    riddle = io.ctx[:ra_riddle]
    io.newline
    if answer?(riddle, input)
      io.ctx.delete(:ra_riddle)
      blessings = io.ctx[:ra_blessings] = io.ctx.fetch(:ra_blessings, 0) + 1
      if blessings >= BLESSINGS && !io.ctx[:ra_blessed]
        io.ctx[:ra_blessed] = true
        speak(io, "Yes. That is #{blessings} riddles, and the blessing is yours: the walls open, and the light finds you.")
        speak(io, game_line(games))
      else
        speak(io, "Yes, little one: #{riddle['answers'].first}. " \
                  "#{blessings < BLESSINGS ? "#{BLESSINGS - blessings} more, and I bless you." : 'The sun is pleased.'}")
      end
    else
      tries = io.ctx[:ra_tries] = io.ctx.fetch(:ra_tries, 0) + 1
      if tries >= 3
        io.ctx.delete(:ra_riddle)
        speak(io, "No. It was #{riddle['answers'].first}. Ask me again when you are ready: RIDDLE.")
      else
        speak(io, tries == 2 ? "No. #{riddle['hint']}" : 'No, little one. Think again.')
      end
    end
  end
end
