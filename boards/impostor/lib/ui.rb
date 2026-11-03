# frozen_string_literal: true

# What the board adds to the impostor gem's debrief terminal on either face:
# its own runner and the goodbye under it.
module UI
  # The debrief terminal as a call step, in a runner of its own: a refused
  # name or code ends the debrief, not the call, so the goodbye still comes.
  def self.debrief(flow) = proc { BBS::FlowRunner.new(session, session_id, flow, context: context).run && nil }

  # The goodbye of a modern terminal, under the debrief's last words.
  def self.goodbye(session) = BBS::Goodbye.modern(session, clear: false)

  # The goodbye of a Commodore 64: a green bar and IMPOSTOR in reversed
  # blocks.
  module Petscii
    include BBS::Petscii::Colors

    LOGO = BBS::BlockFont.petscii('IMPOSTOR', colors: [GN, GN, GN, YE, YE], indent: 2).freeze

    def self.goodbye(session)
      BBS::Goodbye.petscii(session, bar: 'Thanks for calling Impostor BBS', color: GN) do |s|
        LOGO.each { |line| s.puts line }
        s.puts
        s.say("More of us: #{BBS.config.preset.url}", color: GR)
      end
    end
  end
end
