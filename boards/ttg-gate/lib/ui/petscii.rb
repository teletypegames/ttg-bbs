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
    # The node numbers of the C64 callers, for the header.
    NODES = BBS::Nodes.new

    def self.flow(bbs)
      BBS::Flow.define do
        call do |_ctx, runner|
          session = runner.session
          NODES.take do |node|
            Gate.new(session, boards: bbs.directory.boards(petscii: true), browse: bbs.browse, dials: bbs.dials,
                              node: node).run
          end
          Petscii.goodbye(session)
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
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
