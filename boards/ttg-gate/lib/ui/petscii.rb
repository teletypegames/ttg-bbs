# frozen_string_literal: true

require_relative 'colors'
require_relative 'dial'
require_relative 'petscii/gate'

module UI
  # TTG Gate BBS on a Commodore 64: raw PETSCII in the lower/upper set, the
  # frame of UI::Petscii::Gate (the header, the tabs, the hint bar)
  # around our own boards, Global Discovery's lists and pages and the
  # Sources.
  module Petscii
    # The call on a C64: the gate, then its own goodbye.
    def self.call(session, bbs)
      Gate.new(session, boards: bbs.directory.boards(petscii: true), browse: bbs.browse, dials: bbs.dials).run
      goodbye(session)
    end

    def self.goodbye(session)
      canvas = Canvas.new(charset: :lower)
      canvas.text(9, 10, '> Link severed', Canvas::GREEN)
      canvas.text(10, 10, '> Trace wiped', Canvas::GREEN)
      canvas.text(11, 10, '> TTG Gate BBS offline', Canvas::GREEN)
      canvas.text(13, 10, 'See you on the wire', Canvas::DARK_GREY)
      canvas.text(16, 15, 'NO CARRIER', Canvas::LIGHT_GREEN)
      session.write_raw(canvas.frame + [Canvas::LOWERCASE].pack('C*'))
      nil
    end
  end
end
