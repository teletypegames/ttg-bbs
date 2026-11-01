# frozen_string_literal: true

require_relative 'wall_text'
require_relative 'modern/art_lines'
require_relative 'modern/viewer'
require_relative 'modern/canvas_widget'
require_relative 'modern/logo_widget'
require_relative 'modern/helpers'
require_relative 'modern/pane'
require_relative 'modern/years_window'
require_relative 'modern/packs_window'
require_relative 'modern/files_window'
require_relative 'modern/wall_window'
require_relative 'modern/menu'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar; the 16colo.rs gallery as years, packs and files in
  # two-pane windows and a piece on the whole screen; the shared canvas in a
  # window of its own; the Wall with a preview of every work.
  module Modern
    PARTS = [YearsWindow, PacksWindow, FilesWindow, WallWindow, Menu].freeze

    def self.flow(bbs)
      app = application(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          bbs.canvas.leave(ctx[:session_id])
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.modern(runner, title: 'Pixelia BBS')
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.application(bbs)
      BBS::Application.define do
        theme BBS::Theme.synchronet
        services bbs.services
        helpers { include Helpers }
        PARTS.each { |part| part.install(self) }
      end
    end
  end
end
