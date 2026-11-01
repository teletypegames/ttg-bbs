# frozen_string_literal: true

require_relative 'logo'
require_relative 'words'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar, the search in a dialog, lists of games with the card of
  # the one picked on the right, the Wikipedia lead in a scrolling window,
  # the tips of a game in a two-pane window, and a form for a new tip.
  module Modern
    def self.flow(bbs)
      app = BBS::Application.define do
        theme BBS::Theme.synchronet
        services bbs.services

        helpers do
          def catalog = services[:catalog]

          def search
            BBS::Dialogs.input(self, prompt: 'Part of a game title:', title: ' Search ', width: 60,
                                     on_submit: ->(text) { find(text) unless text.strip.empty? })
          end

          def find(query)
            games = catalog.search(query)
            return note(Words.search(games, query), ' Search ') unless games.is_a?(Array) && games.any?

            open_window(:games, title: " Search: #{query.strip} ", games: games)
          end

          def random = open_window(:games, title: ' Random game ', games: [catalog.random])

          def years = open_window(:groups, title: ' Years ', kind: :year, groups: catalog.years)

          def genres = open_window(:groups, title: ' Genres ', kind: :genre, groups: catalog.genres)

          def companies = open_window(:letters)

          def with_tips
            games = services[:tips].games_with_tips
            return note('No game has an approved tip yet. Be the first!', ' Tips ') if games.empty?

            open_window(:games, title: ' Games with tips ', games: games)
          end

          def open_group(kind, name, letter = nil)
            case kind
            when :year    then open_window(:games, title: " #{name} ", games: catalog.in_year(name))
            when :genre   then open_window(:games, title: " #{name} ", games: catalog.of_genre(name))
            when :company then open_window(:games, title: " #{name} ", games: catalog.of_company(name))
            when :letter
              open_window(:groups, title: " Companies: #{letter.upcase} ", kind: :company, groups: catalog.companies(letter))
            end
          end

          def about(game)
            found = with_loading('Asking Wikipedia…') { services[:about].summary(game) }
            return note(Words.about(found), ' About ') if found.is_a?(Symbol)

            open_window(:about, game: game, summary: found)
          end

          def tips(game) = open_window(:tips, game: game, tips: services[:tips].tips(game))

          def add_tip(game) = open_window(:add_tip, game: game)

          def note(text, title) = BBS::Dialogs.message(self, text, title: title, width: 64)

          def selected(window) = window.list_widget.selected_item

          def wrap(text, width) = BBS::FrameBuffer.wrap_ansi(text.to_s, width)

          def about_width = [cols - 4, 78].min

          # The card of +game+ in the right pane of a games window.
          def card(game, width)
            t     = theme
            facts = Words.facts(game)
            pad   = facts.map { |label, _| label.size }.max.to_i + 2
            lines = [*wrap("#{t[:text_bright]}#{game.title}#{t[:text]}", width - 1), '']
            facts.each do |label, text|
              first, *rest = wrap(text, width - 1 - pad)
              lines << "#{t[:label]}#{label.ljust(pad)}#{t[:text]}#{first}"
              rest.each { |r| lines << "#{' ' * pad}#{r}" }
            end
            lines << "#{t[:label]}#{'Tips'.ljust(pad)}#{t[:accent]}#{Words.tips(services[:tips].count(game))}#{t[:text]}"
            lines << ''
            lines << "#{t[:text_dim]}#{game.wikipedia_url}#{t[:text]}" if game.article
            lines << "#{t[:text_dim]}#{game.wikidata_url}#{t[:text]}"
            lines << ''
            lines.concat(wrap("#{t[:text_dim]}Enter or Alt-B: about · Alt-T: tips · Alt-D: add a tip#{t[:text]}", width - 1))
          end

          def status_text = "#{catalog.count} games │ #{Time.now.strftime('%H:%M')}"

          def desktop_label(text, style, x, y, width, align: :left)
            label = BBS::Widgets::Label.new(text: text, align: align, style_key: style)
            label.layout(x, y, width, 1)
            add(label)
          end
        end

        window :games, type: :master_detail do |w|
          w.maximizable true
          w.title         { |ctx| ctx[:title] }
          w.height        { |ctx| ctx[:app].rows - 6 }
          w.list_width    { |ctx| [32, ctx[:app].cols / 3].max }
          w.items         { |ctx| ctx[:games] }
          w.item_label    { |g, _ctx| g.label }
          w.empty_message 'No games here.'
          w.render_detail { |g, width, ctx| ctx[:app].card(g, width) }
          w.bottom_meta   { |g, _ctx| g.id }
          w.on_activate   { |g, _window, ctx| ctx[:app].about(g) }
          w.action(label: 'A&bout') do |win, ctx|
            game = ctx[:app].selected(win)
            ctx[:app].about(game) if game
            :keep
          end
          w.action(label: '&Tips') do |win, ctx|
            game = ctx[:app].selected(win)
            ctx[:app].tips(game) if game
            :keep
          end
          w.action(label: 'A&dd a tip') do |win, ctx|
            game = ctx[:app].selected(win)
            ctx[:app].add_tip(game) if game
            :keep
          end
        end

        window :groups, type: :master_detail do |w|
          w.maximizable true
          w.title         { |ctx| ctx[:title] }
          w.height        { |ctx| ctx[:app].rows - 6 }
          w.list_width    { |ctx| [32, ctx[:app].cols / 3].max }
          w.items         { |ctx| ctx[:groups] }
          w.item_label    { |(name, count), _ctx| "#{name} (#{count})" }
          w.empty_message 'Nothing here.'
          w.render_detail do |(name, count), width, ctx|
            app   = ctx[:app]
            t     = app.theme
            games = case ctx[:kind]
                    when :year then app.catalog.in_year(name)
                    when :genre then app.catalog.of_genre(name)
                    else app.catalog.of_company(name)
                    end
            ["#{t[:text_bright]}#{name}#{t[:text]}", "#{t[:accent]}#{count} game#{'s' unless count == 1}#{t[:text]}", '',
             *games.first(40).map { |g| BBS::FrameBuffer.clip_ansi(g.label, width - 1) },
             *(games.size > 40 ? ["#{t[:text_dim]}… and #{games.size - 40} more#{t[:text]}"] : [])]
          end
          w.bottom_meta { |_item, _ctx| 'Enter lists the games' }
          w.on_activate { |(name, _count), _window, ctx| ctx[:app].open_group(ctx[:kind], name) }
        end

        window :letters, type: :master_detail do |w|
          w.title      ' Publishers & developers '
          w.height     { |ctx| ctx[:app].rows - 6 }
          w.list_width 20
          w.items      { |ctx| ctx[:catalog].letters }
          w.item_label { |(letter, count), _ctx| "#{letter.upcase}  (#{count})" }
          w.render_detail do |(letter, _count), width, ctx|
            t = ctx[:app].theme
            names = ctx[:catalog].companies(letter).map(&:first)
            ["#{t[:text_bright]}#{letter.upcase}#{t[:text]}", '', *ctx[:app].wrap(names.join(' · '), width - 1)]
          end
          w.bottom_meta { |_item, _ctx| 'Enter lists the companies' }
          w.on_activate { |(letter, _count), _window, ctx| ctx[:app].open_group(:letter, nil, letter) }
        end

        window :about, type: :info do |w|
          w.maximizable true
          w.scroll true
          w.title  { |ctx| " #{ctx[:game].title} " }
          w.width  { |ctx| ctx[:app].about_width }
          w.height { |ctx| ctx[:app].rows - 6 }
          w.body do |ctx|
            app = ctx[:app]
            s   = ctx[:summary]
            t   = app.theme
            inner = app.about_width - 5
            ["#{t[:text_bright]}#{s.title}#{t[:text]}", '',
             *s.paragraphs.flat_map { |p| [*app.wrap(p, inner), ''] },
             "#{t[:text_dim]}#{SummaryModel::LICENSE}#{t[:text]}",
             *app.wrap("#{t[:text_dim]}#{s.url}#{t[:text]}", inner)]
          end
        end

        window :tips, type: :master_detail do |w|
          w.maximizable true
          w.title         { |ctx| " Tips: #{ctx[:game].title} " }
          w.height        { |ctx| ctx[:app].rows - 6 }
          w.list_width    26
          w.items         { |ctx| ctx[:tips] }
          w.item_label    { |tip, _ctx| "#{tip.author} · #{tip.date}" }
          w.empty_message 'No tips yet. Add the first one!'
          w.render_detail do |tip, width, ctx|
            t = ctx[:app].theme
            ["#{t[:accent]}#{tip.author}#{t[:text_dim]} · #{tip.date}#{t[:text]}", '', *ctx[:app].wrap(tip.text, width - 1)]
          end
          w.bottom_meta { |tip, _ctx| "tip ##{tip.id}" }
          w.action(label: 'A&dd a tip') do |_win, ctx|
            ctx[:app].add_tip(ctx[:game])
            :keep
          end
        end

        window :add_tip, type: :form do |w|
          w.title { |ctx| " A tip for #{ctx[:game].title} " }
          w.width 70
          w.hint  "Up to #{TipService::MAX_TEXT} characters; an admin reads it first. Alt-S sends."
          w.field :handle, label: 'Your handle', max_length: TipService::MAX_HANDLE, placeholder: 'optional'
          w.field :text, type: :textarea, rows: 6, max_length: TipService::MAX_TEXT
          w.submit_label '&Send'
          w.on_submit do |values, form, ctx|
            app    = ctx[:app]
            result = app.services[:tips].submit(ctx[:game], text: values[:text], handle: values[:handle],
                                                            session: app.session_id)
            if result == :ok
              app.note(Words.tip(result), ' Thanks ')
              :close
            else
              form.error(Words.tip(result))
              :keep
            end
          end
        end

        menubar do
          menu '&Games' do
            item '&Search…',     shortcut: 'F2' do search end
            item '&Random game', shortcut: 'F3' do random end
            separator
            item 'By &year'      do years end
            item 'By &genre'     do genres end
            item 'By &company'   do companies end
            item 'With &tips'    do with_tips end
            separator
            item '&Log off', shortcut: 'Alt-X' do :halt end
          end
          menu '&Help' do
            item '&About'   do note(Words::ABOUT, ' About ') end
            item '&Sources' do note(Words::SOURCES, ' Sources ') end
            item '&Keys' do
              note('F2 Search · F3 Random game · Enter — about the game · Alt+letter — the buttons and the menus · ' \
                   'Tab/Shift-Tab — move focus · Esc — close window · F5 or Alt-Enter — full screen and back · ' \
                   'F6 / Shift-F6 — next / previous window · F10 Menu · Alt-X Log off', ' Keys ')
            end
          end
        end

        status_hint('F2',  'Search') { search }
        status_hint('F3',  'Random') { random }
        status_hint('F10', 'Menu') { menubar.open(0) }
        status_hint('Alt-X', 'Bye') { :halt }

        on_tick { statusbar.right_text = status_text }

        init do
          mark = ((cols - Logo.half_blocks.first.length) / 2) + 1
          Logo.half_blocks.each_with_index { |row, i| desktop_label(row, :accent, mark, 2 + i, row.length) }
          desktop_label("─── #{Words::TAGLINE} ───", :text_dim, 1, 6, cols, align: :center)
          desktop_label('F2 search · F3 random game · F10 menu: years, genres, companies, tips', :text_dim, 1, rows - 2, cols,
                        align: :center)
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
          BBS::Goodbye.modern(runner, title: 'Commodex BBS',
                                      note: 'Games from wikidata.org (CC0), stories from wikipedia.org (CC BY-SA).')
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
