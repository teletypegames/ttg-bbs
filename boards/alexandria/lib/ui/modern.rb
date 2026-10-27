# frozen_string_literal: true

module UI
  # The proxy on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar, the search in a dialog, the results and the article in
  # two-pane windows that can fill the screen.
  module Modern
    LANGUAGES = { 'en' => 'English', 'hu' => 'Magyar', 'de' => 'Deutsch' }.freeze

    TITLE = [
      '██   ██ ██ ██  ██ ██ █████  █████   ████  ██   ██ ██  ██',
      '██   ██ ██ ██ ██  ██ ██  ██ ██  ██ ██  ██  ██ ██   ████ ',
      '██ █ ██ ██ ████   ██ █████  █████  ██  ██   ███     ██  ',
      '███████ ██ ██ ██  ██ ██     ██  ██ ██  ██  ██ ██    ██  ',
      ' ██ ██  ██ ██  ██ ██ ██     ██  ██  ████  ██   ██   ██  '
    ].freeze

    def self.flow(wikipedia)
      app = BBS::Application.define do
        theme BBS::Theme.synchronet
        services wikipedia: wikipedia

        helpers do
          def lang = context[:lang]

          def language_name = LANGUAGES.fetch(lang, lang)

          def search
            BBS::Dialogs.input(self, prompt: "Article title on #{lang}.wikipedia.org:", title: ' Search ', width: 60,
                                     on_submit: ->(text) { look_up(text) unless text.strip.empty? })
          end

          # The article titled as typed opens at once; otherwise the results.
          def look_up(query)
            article, results = with_loading('Searching Wikipedia…') { services[:wikipedia].look_up(query, lang: lang) }
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
            article = with_loading('Loading the article…') { services[:wikipedia].article(title, lang: lang) }
            if article
              open_window(:article, article: article)
            else
              BBS::Dialogs.message(self, "Wikipedia has no article \"#{title}\", or did not answer.", title: ' Article ')
            end
          end

          def random
            title = with_loading('Picking an article…') { services[:wikipedia].random(lang: lang) }
            title ? read(title) : BBS::Dialogs.message(self, 'Wikipedia did not answer. Try again later.', title: ' Random ')
          end

          def switch_language
            context[:lang] = services[:wikipedia].next_language(lang)
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
                'WikiProxy — Wikipedia on a telnet line, from Teletype Games, powered by rubbs. ' \
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

        on_tick { statusbar.right_text = status_text }

        init do
          context[:lang] ||= services[:wikipedia].languages.first
          top = [((rows - 15) / 2) - TITLE.size, 2].max
          lines = [*TITLE.map { |l| [l, :accent] }, ['', :text],
                   ['Wikipedia on a telnet line', :text_bright],
                   ['F2 search · F3 random article · F4 language · Alt-X log off', :text_dim]]
          lines.each_with_index do |(text, style), i|
            label = BBS::Widgets::Label.new(text: text, align: :center, style_key: style)
            label.layout(1, top + i, cols, 1)
            add(label)
          end
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
          runner.write "\e[0m\e[2J\e[H\r\n  \e[1;37mThanks for calling WikiProxy.\e[0m\r\n  " \
                       "\e[2;37mArticles from wikipedia.org, under CC BY-SA. More of us: teletypegames.org\e[0m\r\n\r\n  " \
                       "\e[1;31mNO CARRIER\e[0m\r\n\r\n"
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
