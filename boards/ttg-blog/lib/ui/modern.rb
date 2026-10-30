# frozen_string_literal: true

require_relative 'board'
require_relative 'modern/board'

module UI
  # The blog on a modern terminal (ANSI colours, UTF-8): the line-by-line
  # board on the caller's window. It works on the same TtgblogBBS as the
  # PETSCII face.
  module Modern
    def self.flow(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          board = Board.new(bbs, Board.screen(runner.session), ctx)
          board.run
          board.goodbye
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
