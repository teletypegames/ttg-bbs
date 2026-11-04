# frozen_string_literal: true

require_relative 'colors'
require_relative 'dial'
require_relative 'account'
require_relative 'modern/style'
require_relative 'modern/own_servers'
%w[context menu_view list_view board_page sources home].each { |f| require_relative "modern/discovery/#{f}" }
require_relative 'modern/gate'

module UI
  # TTG Gate BBS on a modern terminal: the chooser of Own Servers (the
  # dialing menu of UI::Modern::OwnServers) and Global Discovery
  # (UI::Modern::Discovery::Home), pages of UI::Modern::Gate. TAB turns from
  # one to the other; each keeps its place. Q on either hangs up with the
  # goodbye of our boards.
  module Modern
  end
end
