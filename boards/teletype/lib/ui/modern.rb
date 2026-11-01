# frozen_string_literal: true

require_relative 'wording'
require_relative 'modern/formatters'
require_relative 'modern/classic_formatters'
require_relative 'modern/desktop'
require_relative 'modern/rooms'
require_relative 'modern/clubhouse'
require_relative 'modern/steps'
require_relative 'modern/helpers'
require_relative 'modern/windows'
require_relative 'modern/menus'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): the modem
  # and the logon matrix, then a desktop of windows under a menubar.
  module Modern
    def self.flow(bbs)
      desktop = desktop(bbs)
      BBS::Flow.define do
        call { |ctx, runner| Steps.entrance(bbs, ctx, runner) }
        call { |ctx, runner| Steps.logon(bbs, ctx, runner) }
        call do |ctx, runner|
          desktop.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          nil
        end
        call { |ctx, runner| Steps.leaving(bbs, ctx, runner) }
      end
    end

    # The desktop: the windows (Windows), the menubar (Menus), the status
    # keys, the doors, and what runs every second (Helpers#tick).
    def self.desktop(bbs)
      BBS::Application.define do
        theme BBS::Theme.neumanntronics
        Modern.doors(self, bbs)
        services bbs.services
        helpers { include Helpers }
        Windows.define(self)
        menubar { Menus.define(self) }
        Modern.status_keys(self)
        on_tick { tick }
        init { furnish }
      end
    end

    # Doors: full-line programs a caller can step into from the Doors menu.
    # The BBS hands the telnet line over and takes it back when the program exits.
    def self.doors(app, bbs)
      bbs.doors.each { |d| app.door d.name, d.program, label: d.label, hint: d.hint }
      app.on_door { |door, ctx| bbs.online.activity(ctx[:session_id], "Door: #{door.label.delete('&')}") }
    end

    def self.status_keys(app)
      app.status_hint('F1',  'Ask')    { open_window(:master) }
      app.status_hint('F2',  'Boards') { open_window(:messages) }
      app.status_hint('F3',  'Post', hidden: true) { open_new_post }
      app.status_hint('F4',  'Chat')   { open_window(:chat) }
      app.status_hint('F7',  'Mail')   { open_mail }
      app.status_hint('F10', 'Menu')   { menubar.open(0) }
      app.status_hint('Alt-X', 'Bye')  { :halt }
    end
  end
end
