# frozen_string_literal: true

require_relative 'colors'
require_relative 'dial'
require_relative 'modern/selector'

module UI
  # TTG Gate BBS on a modern terminal: the dialing menu of UI::Modern::Selector.
  module Modern
    def self.flow(bbs)
      BBS::Flow.define do
        call do |_ctx, runner|
          Selector.new(runner.session, bbs.directory.boards).run
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
