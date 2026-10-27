# frozen_string_literal: true

module UI
  # The reader on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar, the feeds in a two-pane window, a feed's items with the
  # one picked on the right, and two forms that write to the admins.
  module Modern
    # A newspaper's masthead in half blocks, two rows: the feed windows
    # leave two rows of the desktop above them, and two below.
    MASTHEAD = [
      '█▀▀ █▀▀ █▀▀ █▀▄ █ ▄▀█',
      '█▀  ██▄ ██▄ █▄▀ █ █▀█'
    ].freeze

    def self.flow(feeds, inbox)
      app = BBS::Application.define do
        theme BBS::Theme.synchronet
        services feeds: feeds, inbox: inbox

        helpers do
          def feed_list = open_window(:feeds)

          def open_feed(feed)
            channel = with_loading("Fetching #{feed.name}…") { services[:feeds].read(feed) }
            if channel
              open_window(:channel, channel: channel)
            else
              BBS::Dialogs.message(self, "#{feed.name} did not answer, or what it sent is not a feed. Try again later.",
                                   title: ' Feed ')
            end
          end

          def reload(window, channel)
            fresh = with_loading("Fetching #{channel.feed.name}…") { services[:feeds].read(channel.feed, fresh: true) }
            if fresh
              window.replace_items(fresh.items, title: " #{fresh.title} ")
            else
              BBS::Dialogs.message(self, "#{channel.feed.name} did not answer. Try again later.", title: ' Reload ')
            end
          end

          # Five messages a call: enough for anyone, too few for a flood.
          def can_send?
            return true if context[:sent].to_i < Inbox::PER_CALL

            BBS::Dialogs.message(self, 'That is all the messages one call can send. Thank you!', title: ' Admins ')
            false
          end

          def sent!
            context[:sent] = context[:sent].to_i + 1
            BBS::Dialogs.message(self, 'Sent to the admins. Thank you!', title: ' Admins ')
          end

          def suggest = can_send? && open_window(:suggest)

          def feedback = can_send? && open_window(:feedback)

          def status_text = "#{services[:feeds].list.size} feeds │ #{Time.now.strftime('%H:%M')}"

          def desktop_label(text, style, x, y, width, align: :left)
            label = BBS::Widgets::Label.new(text: text, align: align, style_key: style)
            label.layout(x, y, width, 1)
            add(label)
          end

          def markdown(text, width) = BBS::Markdown.to_lines(text, width: width - 1, theme: theme)
        end

        window :feeds, type: :master_detail do |w|
          w.maximizable true
          w.title         ' Feeds '
          w.list_width    { |ctx| [30, ctx[:app].cols / 3].max }
          w.items         { |ctx| ctx[:feeds].list }
          w.item_label    { |f, _ctx| f.name }
          w.empty_message 'No feeds are configured.'
          w.render_detail do |f, width, ctx|
            t = ctx[:app].theme
            ["#{t[:text_bright]}#{f.name}#{t[:text]}",
             "#{t[:accent]}#{[f.group, f.lang].reject(&:empty?).join(' · ')}#{t[:text]}", '',
             *BBS::FrameBuffer.wrap_ansi(f.about, width - 1), '',
             *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}#{f.url}#{t[:text]}", width - 1)]
          end
          w.bottom_meta { |_f, _ctx| 'Enter opens the feed' }
          w.on_activate { |f, _window, ctx| ctx[:app].open_feed(f) }
          w.action(label: '&Open') do |win, ctx|
            feed = win.list_widget.selected_item
            ctx[:app].open_feed(feed) if feed
            :keep
          end
        end

        window :channel, type: :master_detail do |w|
          w.maximizable true
          w.title         { |ctx| " #{ctx[:channel].title} " }
          w.list_width    { |ctx| [30, ctx[:app].cols / 3].max }
          w.items         { |ctx| ctx[:channel].items }
          w.item_label    { |item, _ctx| item.title }
          w.empty_message 'This feed has nothing in it right now.'
          w.render_detail do |item, width, ctx|
            t      = ctx[:app].theme
            byline = [item.date&.localtime&.strftime('%Y-%m-%d %H:%M'), item.author].compact.reject(&:empty?).join(' · ')
            lines  = ctx[:app].markdown("# #{item.title}", width)
            lines << "#{t[:text_dim]}#{byline}#{t[:text]}" unless byline.empty?
            lines << ''
            lines.concat(ctx[:app].markdown(item.markdown.empty? ? '*(no text in the feed)*' : item.markdown, width))
            lines
          end
          w.bottom_meta { |item, _ctx| item.link.to_s }
          w.action(label: '&Reload') do |win, ctx|
            ctx[:app].reload(win, ctx[:channel])
            :keep
          end
        end

        window :suggest, type: :form do |w|
          w.title ' Suggest a feed '
          w.width 70
          w.hint  'Why this feed? Write it in the box below (optional). Alt-S sends.'
          w.field :url,  label: 'Feed address', max_length: Inbox::MAX_FIELD, placeholder: 'https://…'
          w.field :name, label: 'Its name', max_length: Inbox::MAX_FIELD
          w.field :from, label: 'Your name', max_length: Inbox::MAX_FIELD, placeholder: 'optional'
          w.field :note, type: :textarea, rows: 4, max_length: Inbox::MAX_TEXT
          w.submit_label '&Send'
          w.on_submit do |values, form, ctx|
            case ctx[:inbox].suggest(**values)
            when :ok      then ctx[:app].sent!; :close
            when :no_url  then form.error('The address of the feed, please.'); :keep
            when :bad_url then form.error('That is not an http:// or https:// address.'); :keep
            else form.error('The message could not be saved. Try again later.'); :keep
            end
          end
        end

        window :feedback, type: :form do |w|
          w.title ' Feedback to the admins '
          w.width 70
          w.hint  'A bug, an idea, a word of thanks: write it below. Alt-S sends.'
          w.field :from, label: 'Your name', max_length: Inbox::MAX_FIELD, placeholder: 'optional'
          w.field :text, type: :textarea, rows: 8, max_length: Inbox::MAX_TEXT
          w.submit_label '&Send'
          w.on_submit do |values, form, ctx|
            case ctx[:inbox].feedback(**values)
            when :ok    then ctx[:app].sent!; :close
            when :empty then form.error('Write something first.'); :keep
            else form.error('The message could not be saved. Try again later.'); :keep
            end
          end
        end

        menubar do
          menu '&Feeds' do
            item '&Feed list', shortcut: 'F2' do feed_list end
            separator
            item '&Log off', shortcut: 'Alt-X' do :halt end
          end
          menu '&Admins' do
            item '&Suggest a feed…', shortcut: 'F7' do suggest end
            item 'Send &feedback…',  shortcut: 'F8' do feedback end
          end
          menu '&Help' do
            item '&About' do
              BBS::Dialogs.message(self,
                'Feedia — an RSS reader on a telnet line, from Teletype Games, powered by rubbs. ' \
                'Pick a feed, then an item: its text opens on the right, its links numbered under it. ' \
                'A feed missing from the list? Suggest it in the Admins menu.',
                title: ' About ', width: 64)
            end
            item '&Keys' do
              BBS::Dialogs.message(self,
                'F2 Feeds · F7 Suggest a feed · F8 Feedback · Alt+letter — open menu · ' \
                'Tab/Shift-Tab — move focus · Enter — open · Esc — close window · ' \
                'F5 or Alt-Enter — full screen and back · F6 / Shift-F6 — next / previous window · ' \
                'F10 Menu · Alt-X Log off',
                title: ' Keys ', width: 64)
            end
          end
        end

        status_hint('F2',  'Feeds') { feed_list }
        status_hint('F7',  'Suggest') { suggest }
        status_hint('F8',  'Feedback') { feedback }
        status_hint('F10', 'Menu') { menubar.open(0) }
        status_hint('Alt-X', 'Bye') { :halt }

        on_tick { statusbar.right_text = status_text }

        init do
          left  = ['VOL. I · NO. 2327', 'THE TELNET EDITION']
          right = [Time.now.strftime('%A %-d %b %Y').upcase, "#{services[:feeds].list.size} FEEDS · NO CHARGE"]
          mark  = ((cols - MASTHEAD.first.length) / 2) + 1
          ear   = mark - 4
          MASTHEAD.each_with_index do |row, i|
            desktop_label(row, :accent, mark, 2 + i, row.length)
            desktop_label(left[i], :text_dim, 3, 2 + i, ear)
            desktop_label(right[i], :text_dim, mark + row.length + 2, 2 + i, ear, align: :right)
          end
          desktop_label('─── All the news that fits in 80 columns ───', :text_dim, 1, rows - 1, cols, align: :center)
          statusbar.right_text = status_text
          feed_list
        end
      end

      BBS::Flow.define do
        call do |ctx, runner|
          app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          nil
        end
        call do |_ctx, runner|
          runner.write "\e[0m\e[2J\e[H\r\n  \e[1;37mThanks for calling Feedia.\e[0m\r\n  " \
                       "\e[2;37mThe stories are their publishers'. More of us: teletypegames.org\e[0m\r\n\r\n  " \
                       "\e[1;31mNO CARRIER\e[0m\r\n\r\n"
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
