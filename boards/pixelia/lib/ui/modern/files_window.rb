# frozen_string_literal: true

module UI
  module Modern
    # The text-art files of a pack on the left, the SAUCE facts of the one
    # picked on the right.
    module FilesWindow
      module_function

      def install(app)
        app.window(:files, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        w.title { |ctx| " #{ctx[:pack].name} " }
        Pane.size(w) { |app| [24, app.cols / 3].max }
        w.items         { |ctx| ctx[:files] }
        w.item_label    { |f, _ctx| f.name }
        w.empty_message 'No text art in this pack.'
        w.render_detail { |f, width, ctx| detail(f, width, ctx[:app]) }
        w.bottom_meta   { |_f, _ctx| 'Enter shows it' }
        w.on_activate   { |f, _window, ctx| ctx[:app].view_piece(f) }
        w.action(label: '&View') { |win, ctx| view_selected(win, ctx[:app]) }
      end

      def view_selected(win, app) = app.with_selected(win) { |f| app.view_piece(f) }

      def detail(file, width, app)
        t = app.theme
        ["#{t[:text_bright]}#{file.name}#{t[:text]}", "#{t[:accent]}#{file.credits}#{t[:text]}", '',
         *facts(file).map { |k, v| "#{t[:label]}#{k.ljust(8)}#{t[:text]}#{v}" }, '',
         *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}#{app.gallery.file_url(file)}#{t[:text]}", width - 1)]
      end

      def facts(file)
        [['Title', file.title], ['Author', file.author], ['Group', file.group], ['Artists', file.artists.join(', ')],
         ['Date', file.date], ['Width', file.width&.to_s], ['Colours', file.ice? ? 'iCE (16 backgrounds)' : nil]]
          .reject { |_, v| v.to_s.empty? }
      end
    end
  end
end
