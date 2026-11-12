# frozen_string_literal: true

require_relative 'colors'
require_relative 'account'
require_relative 'dial'
require_relative 'today'
require_relative 'modern/style'
require_relative 'modern/prompt'
require_relative 'sysop'
%w[view calls accounts feedback_tab wall_tab log_view].each { |f| require_relative "modern/sysop/#{f}" }
require_relative 'modern/own_servers'
%w[context menu_view list_view board_page sources home].each { |f| require_relative "modern/discovery/#{f}" }
require_relative 'modern/today'
require_relative 'modern/profile_tab'
require_relative 'modern/gate'

module UI
  # TTG Gate BBS on a modern terminal: the chooser of Own Servers (the
  # dialing menu of UI::Modern::OwnServers) and Global Discovery
  # (UI::Modern::Discovery::Home) and Today (UI::Modern::Today), pages of
  # UI::Modern::Gate. TAB turns from
  # one to the other; each keeps its place. Q on either hangs up with the
  # goodbye of our boards. A sysop opens the console (UI::Modern::Sysop)
  # from SysOp in the profile.
  module Modern
  end
end
