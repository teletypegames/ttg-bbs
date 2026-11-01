# frozen_string_literal: true

require_relative 'modern/pharos'

module UI
  # The proxy on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar, the search in a dialog, the results and the article in
  # two-pane windows that can fill the screen.
  module Modern
    LANGUAGES = { 'en' => 'English', 'hu' => 'Magyar', 'de' => 'Deutsch' }.freeze

    def self.flow(bbs)
      app = BBS::Application.define do
        theme BBS::Theme.synchronet
        services bbs.services

        helpers do
          def lang = context[:lang]

          def language_name = LANGUAGES.fetch(lang, lang)

          def search
            BBS::Dialogs.input(self, prompt: "Article title on #{lang}.wikipedia.org:", title: ' Search ', width: 60,
                                     on_submit: ->(text) { look_up(text) unless text.strip.empty? })
          end

          # The article titled as typed opens at once; otherwise the results.
          def look_up(query)
            article, results = with_loading('Searching Wikipedia…') { services[:articles].look_up(query, lang: lang) }
            if article
              open_window(:article, article: article)
            elsif results.nil?
              BBS::Dialogs.message(self, 'Wikipedia did not answer. Try again later.', title: ' Search ')
            elsif results.empty?
              BBS::Dialogs.message(self, "Nothing found for \"#{query}\" on #{lang}.wikipedia.org.", title: ' Search ')
            else
              open_window(:results, query: query, results: results)
            end
          end

          def read(title)
            article = with_loading('Loading the article…') { services[:articles].article(title, lang: lang) }
            if article
              open_window(:article, article: article)
            else
              BBS::Dialogs.message(self, "Wikipedia has no article \"#{title}\", or did not answer.", title: ' Article ')
            end
          end

          def random
            title = with_loading('Picking an article…') { services[:articles].random(lang: lang) }
            title ? read(title) : BBS::Dialogs.message(self, 'Wikipedia did not answer. Try again later.', title: ' Random ')
          end

          def switch_language
            context[:lang] = services[:articles].next_language(lang)
            statusbar.right_text = status_text
            BBS::Dialogs.message(self, "Searching #{lang}.wikipedia.org (#{language_name}) from now on.", title: ' Language ')
          end

          def status_text = "#{lang}.wikipedia.org │ #{Time.now.strftime('%H:%M')}"

          def markdown(text, width) = BBS::Markdown.to_lines(text, width: width - 1, theme: theme)
        end

        window :results, type: :master_detail do |w|
          w.maximizable true
          w.title         { |ctx| " Search: #{ctx[:query]} " }
          w.list_width    { |ctx| [30, ctx[:app].cols / 3].max }
          w.items         { |ctx| ctx[:results] }
          w.item_label    { |r, _ctx| r.title }
          w.render_detail do |r, width, ctx|
            t = ctx[:app].theme
            ["#{t[:text_bright]}#{r.title}#{t[:text]}", '',
             *BBS::FrameBuffer.wrap_ansi("…#{r.snippet}…", width - 1)]
          end
          w.bottom_meta { |r, _ctx| "#{r.words} words · Enter opens it" }
          w.on_activate { |r, _window, ctx| ctx[:app].read(r.title) }
          w.action(label: '&Open') do |win, ctx|
            item = win.list_widget.selected_item
            ctx[:app].read(item.title) if item
            :keep
          end
        end

        window :article, type: :master_detail do |w|
          w.maximizable true
          w.title         { |ctx| " #{ctx[:article].title} " }
          w.list_width    { |ctx| [26, ctx[:app].cols / 4].max }
          w.items         { |ctx| ctx[:article].sections }
          w.item_label    { |s, _ctx| s.title }
          w.render_detail do |s, width, ctx|
            article = ctx[:article]
            t       = ctx[:app].theme
            lines   = ctx[:app].markdown("# #{s.title}\n\n#{s.markdown}", width)
            if s == article.sections.first && article.redirected_from
              lines.insert(1, "#{t[:text_dim]}(Redirected from #{article.redirected_from})#{t[:text]}")
            end
            lines
          end
          w.bottom_meta { |_s, ctx| "#{ctx[:article].url} · CC BY-SA" }
        end

        menubar do
          menu '&Wiki' do
            item '&Search…',        shortcut: 'F2' do search end
            item '&Random article', shortcut: 'F3' do random end
            item '&Language…',      shortcut: 'F4' do switch_language end
            separator
            item '&Log off', shortcut: 'Alt-X' do :halt end
          end
          menu '&Help' do
            item '&About' do
              BBS::Dialogs.message(self,
                'Alexandria BBS — Wikipedia on a telnet line, from Teletype Games, powered by rubbs. ' \
                'Type a title: the article of that title opens at once, otherwise the search results. ' \
                'An article opens with its sections on the left. ' \
                "The text is Wikipedia's, under CC BY-SA; the address is under each article.",
                title: ' About ', width: 64)
            end
            item '&Keys' do
              BBS::Dialogs.message(self,
                'F2 Search · F3 Random article · F4 Language · Alt+letter — open menu · ' \
                'Tab/Shift-Tab — move focus · Enter — open · Esc — close window · ' \
                'F5 or Alt-Enter — full screen and back · F6 / Shift-F6 — next / previous window · ' \
                'F10 Menu · Alt-X Log off',
                title: ' Keys ', width: 64)
            end
          end
        end

        status_hint('F2',  'Search') { search }
        status_hint('F3',  'Random') { random }
        status_hint('F4',  'Language') { switch_language }
        status_hint('F10', 'Menu') { menubar.open(0) }
        status_hint('Alt-X', 'Bye') { :halt }

        on_tick do
          @pharos.tick
          statusbar.right_text = status_text
        end

        init do
          context[:lang] ||= services[:articles].languages.first
          dialog_top = ((rows - 7) / 2) + 1
          @pharos = add(Pharos.new)
          @pharos.layout(1, [dialog_top - Pharos::HEIGHT - 1, 2].max, cols, Pharos::HEIGHT)
          help = BBS::Widgets::Label.new(text: 'F2 search · F3 random article · F4 language · Alt-X log off',
                                         align: :center, style_key: :text_dim)
          help.layout(1, dialog_top + 8, cols, 1)
          add(help)
          statusbar.right_text = status_text
          search
        end
      end

      BBS::Flow.define do
        call do |ctx, runner|
          app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.modern(runner, title: 'Alexandria BBS', note: 'Articles from wikipedia.org, under CC BY-SA.')
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
