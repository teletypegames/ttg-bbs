# frozen_string_literal: true

require_relative 'wording'
require_relative 'modern/formatters'
require_relative 'modern/classic_formatters'
require_relative 'modern/desktop'
require_relative 'modern/rooms'
require_relative 'modern/clubhouse'
require_relative 'modern/logon'
require_relative 'modern/section'
require_relative 'modern/helpers'
require_relative 'modern/menus'
require_relative 'modern/windows/board'
require_relative 'modern/windows/messages'
require_relative 'modern/windows/mail'
require_relative 'modern/windows/chat'
require_relative 'modern/windows/people'
require_relative 'modern/windows/you'
require_relative 'modern/windows/doors'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): after the
  # modem and the logon matrix, a desktop of windows under a menubar, the
  # clubhouse from the street on it.
  module Modern
    APP = BBS::Application.define do
      theme :neumanntronics
      helpers { include Helpers }
      init { count_mail }
      on_tick { tick }
      status(clock: :before) { status_text }
      doors { board.doors }
      on_door { |door, context| board.enter_door(context[:session_id], door) }

      desktop do
        widget(fill: true) { Dashboard.new }
        on_show { refresh_dashboard }
        button(Formatters::Master::DESKTOP_LABEL, bottom: 1, align: :right, margin: 2) { open_master }
      end

      parts Menus, Windows::Board, Windows::Messages, Windows::Mail, Windows::Chat, Windows::People, Windows::You, Windows::Doors
    end
  end
end
