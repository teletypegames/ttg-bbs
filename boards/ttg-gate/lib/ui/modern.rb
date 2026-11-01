# frozen_string_literal: true

require_relative 'colors'
require_relative 'dial'
require_relative 'modern/style'
require_relative 'modern/selector'
%w[context prompt menu_view list_view board_page sources home].each { |f| require_relative "modern/discovery/#{f}" }

module UI
  # TTG Gate BBS on a modern terminal: the chooser of Own Servers (the
  # dialing menu of UI::Modern::Selector) and Global Discovery
  # (UI::Modern::Discovery::Home). TAB turns from one to the other; each keeps
  # its place.
  module Modern
    def self.flow(bbs)
      BBS::Flow.define do
        call do |_ctx, runner|
          session = runner.session
          sides = { own: Selector.new(session, bbs.directory.boards),
                    discovery: Discovery::Home.new(session, bbs.browse, bbs.dials) }
          side = :own
          side = side == :own ? :discovery : :own while sides[side].run == :switch
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
