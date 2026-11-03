# frozen_string_literal: true

module UI
  module Modern
    # The Jargon File on the modern face: the helpers of the Application
    # (the word of the day, the letters, the search, a random entry, the
    # chapters, an entry in a TextWindow with its links) and the windows of
    # its lists (JargonWindows).
    module Jargon
      def jargon = services[:jargon]

      def jargon_today = open_jargon(jargon.word_of_the_day, 'Word of the day: ')

      def jargon_random = open_jargon(jargon.random)

      def jargon_letters
        return jargon_preparing unless jargon.ready?

        open_window(:jargon_letters, letters: jargon.letters)
      end

      def jargon_letter(letter)
        list = jargon.letter(letter)
        open_window(:jargon_entries, entries: list, title: " Jargon: #{letter == '0' ? '0-9' : letter} (#{list.size}) ")
      end

      def jargon_search
        return jargon_preparing unless jargon.ready?

        BBS::Dialogs.input(self, prompt: 'Words of a headword or of the text:', title: ' Search the lexicon ',
                                 value: context[:jargon_query].to_s, width: 64, on_submit: ->(query) { jargon_find(query) })
      end

      def jargon_find(query)
        context[:jargon_query] = query
        case (found = jargon.search(query))
        when :too_short then BBS::Dialogs.message(self, 'A word of two letters or more, please.', title: ' Jargon ')
        when [] then BBS::Dialogs.message(self, 'No entry has these words.', title: ' Jargon ')
        else open_window(:jargon_entries, entries: found, title: " Jargon: #{query.strip[0, 40]} (#{found.size}) ")
        end
      end

      def jargon_chapters
        return jargon_preparing unless jargon.ready?

        open_window(:jargon_sections, sections: jargon.sections)
      end

      # An entry in a TextWindow: the headword, its pronunciation, the text
      # with its {links}, and the File's credit under it.
      def open_jargon(entry, prefix = '')
        return jargon_preparing unless entry

        TextWindow.open(self, title: "#{prefix}#{entry.headword}", where: JargonService::CREDIT,
                              paragraphs: [[:heading, [entry.headword, entry.pron].reject(&:empty?).join('  ')],
                                           *entry.paragraphs],
                              buttons: [jargon_button('&Links') { jargon_links(entry) },
                                        jargon_button('Ra&ndom') { jargon_random }])
        :keep
      end

      def jargon_links(entry)
        list = jargon.links(entry)
        return BBS::Dialogs.message(self, "#{entry.headword} links to no other entry.", title: ' Links ') if list.empty?

        open_window(:jargon_entries, entries: list, title: " Links of #{entry.headword} (#{list.size}) ")
      end

      def open_section(section)
        TextWindow.open(self, title: section.title, paragraphs: section.paragraphs, where: JargonService::CREDIT)
        :keep
      end

      def jargon_preparing
        BBS::Dialogs.message(self, 'The Jargon File is being prepared. Try again in a moment.', title: ' Jargon File ')
      end

      private

      def jargon_button(label, &action) = { label: label, keep_open: true, align: :left, on_click: ->(_w) { action.call } }
    end

    # The list windows of the Jargon File: the letters, a list of entries
    # (the entry on the right; Enter opens it), the chapters.
    module JargonWindows
      def self.define(app)
        letters(app)
        entries(app)
        sections(app)
      end

      def self.frame(w, title, list_width)
        w.maximizable true
        w.title         title
        w.height        { |ctx| ctx[:app].rows - 8 }
        w.list_width    { |ctx| [list_width, (ctx[:app].cols / 2) - 4].min }
      end

      def self.letters(app)
        app.window(:jargon_letters, type: :master_detail) do |w|
          frame(w, ' The Jargon Lexicon ', 20)
          w.items         { |ctx| ctx[:letters] }
          w.item_label    { |(l, _), _ctx| l == '0' ? '0-9 and signs' : l }
          w.render_detail { |(_, n), _width, _ctx| ["#{n} entries", '', 'Enter lists them.'] }
          w.on_activate { |(l, _), _window, ctx| ctx[:app].jargon_letter(l) }
        end
      end

      def self.entries(app)
        app.window(:jargon_entries, type: :master_detail) do |w|
          frame(w, ->(ctx) { ctx[:title] }, 30)
          w.items         { |ctx| ctx[:entries] }
          w.item_label    { |e, _ctx| e.headword }
          w.empty_message 'No entries.'
          w.render_detail { |e, width, ctx| entry_lines(e, width, ctx[:app].theme) }
          w.bottom_meta { |_e, _ctx| JargonService::CREDIT }
          w.on_activate { |e, _window, ctx| ctx[:app].open_jargon(e) }
          entry_actions(w)
        end
      end

      def self.entry_actions(w)
        w.action(label: '&Read') { |win, ctx| on_selected(win, ctx) { |e| ctx[:app].open_jargon(e) } }
        w.action(label: '&Links') { |win, ctx| on_selected(win, ctx) { |e| ctx[:app].jargon_links(e) } }
      end

      def self.on_selected(window, ctx)
        entry = ctx[:app].selected(window)
        yield entry if entry
        :keep
      end

      def self.sections(app)
        app.window(:jargon_sections, type: :master_detail) do |w|
          frame(w, ' Jargon File: chapters and appendices ', 44)
          w.items         { |ctx| ctx[:sections] }
          w.item_label    { |s, _ctx| s.title }
          w.render_detail do |s, width, _ctx|
            BBS::FrameBuffer.wrap_ansi(s.paragraphs.find { |k, _| k == :text }&.last.to_s[0, 400], width - 1)
          end
          w.on_activate { |s, _window, ctx| ctx[:app].open_section(s) }
        end
      end

      def self.entry_lines(entry, width, t)
        wrap = ->(s) { BBS::FrameBuffer.wrap_ansi(s, width - 1) }
        [*wrap.call("#{t[:text_bright]}#{entry.headword}#{t[:text]} #{t[:text_dim]}#{entry.pron}#{t[:text]}"), '',
         *wrap.call(entry.summary[0, 600]), '', *wrap.call("#{t[:text_dim]}Enter reads it.#{t[:text]}")]
      end
    end
  end
end
