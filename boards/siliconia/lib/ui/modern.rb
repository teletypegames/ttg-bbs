# frozen_string_literal: true

require_relative 'logo'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): the logo on the desktop and
  # the notices in a two-pane window.
  module Modern
    ABOUT = 'Siliconia BBS — a board of the Teletype Games BBS network, powered by rubbs.'

    APP = Rubbs::Modern::Application.define do
      theme :synchronet

      command(:notices, 'Notices', key: 'F2') { show(:notices) }
      menu 'Board', :notices, :separator, :log_off
      help about: ABOUT

      status { "#{notices.all.size} notices" }

      desktop do
        art Logo.half_blocks, top: 1
        on_show { show(:notices) }
      end

      window :notices, :master_detail do
        title 'Notices'
        height(-8)
        items { notices.all }
        label :title
        empty 'No notices are configured.'
        detail { |n| [bright(n.title), '', n.body] }
      end
    end
  end
end
