# frozen_string_literal: true

module UI
  module Modern
    # What the caller does on the modern face: open a directory, read it again,
    # take a title home, the network's feedback and wall.
    module Helpers
      def open_directory(directory)
        show(:titles, directory: directory, titles: read_directory(directory))
      end

      def reload_directory(window, directory)
        window.replace_items(read_directory(directory, fresh: true))
      end

      def download(title, protocol)
        data = loading("Fetching #{title.file}…") { catalog.fetch(title) }
        return tell(Wording.refusal(data, title)) if data.is_a?(Symbol)

        result = with_line { |session| transfer(session, title, protocol, data) }
        catalog.downloaded(title, protocol) if result == :ok
        tell(Rubbs::Common::Files::Transfer.result(result, protocol, title.file))
      end

      # The name, the version and author, the file and its downloads, the
      # about and the two ways to load it.
      def title_card(title)
        count  = catalog.downloads(title)
        byline = [title.version.empty? ? '' : "v#{title.version}", title.author].reject(&:empty?).join(' · ')
        [bright(title.title), accent(byline),
         dim("#{title.file} · #{title.size} bytes · #{count} download#{'s' unless count == 1}"), '', title.about, '',
         "#{paint(:label, 'On a Commodore:')} LOAD\"#{title.disk_name}\",8,1, RUN",
         "#{paint(:label, 'Over HTTP:')} #{catalog.url(title)}"]
      end

      # The network's feedback (ttg-common TTG::Feedback), about the title
      # picked in a directory, if any.
      def feedback
        directory = window(:titles)
        title = directory&.selected
        about = title && "#{directory.title}: #{title.title} v#{title.version} (#{title.file})"
        with_line { TTG::Feedback.open(@session, context: about) }
      end

      # The board's wall (TTG::Wall).
      def wall = with_line { TTG::Wall.open(@session) }

      private

      def read_directory(directory, fresh: false)
        loading("Reading the #{directory.name} directory…", failed: Wording::NO_ANSWER) { catalog.titles(directory, fresh: fresh) }
      end

      def transfer(session, title, protocol, data)
        text = Rubbs::Modern::FrameBuffer.wrap_ansi(
          Rubbs::Common::Files::Transfer.start(protocol, title.file, title.size, save_as: title.disk_name),
          cols - 4
        )
        session.write("\r\n#{text.map { |l| "  #{l}\r\n" }.join}\r\n")
        Rubbs::Common::Files::Transfer.send(session, protocol, title.file, data)
      end

      def tell(text) = message(text, title: 'Download', width: 64)
    end
  end
end
