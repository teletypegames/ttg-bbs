# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # Board > System Info: the board in numbers.
      module SystemInfo
        def self.configure(w)
          w.accent Accent::STYLES[:board]
          w.title  Icon.title(:board, 'System Info')
          w.width  60
          w.height 15
          w.body { |ctx| [{ kv: rows(ctx), label_width: 15 }] }
        end

        def self.rows(ctx)
          [['Nodes in use', ctx[:online].count.to_s],
           ['Calls',        "#{ctx[:last_callers].total_calls} (#{ctx[:last_callers].calls_today} today)"],
           ['Messages',     ctx[:boards].total_count.to_s],
           ['Boards',       ctx[:boards].boards.size.to_s],
           ['Wiki',         'https://wiki.teletypegames.org'],
           ['Games API',    'https://teletypegames.org'],
           ['Discord feed', ctx[:discord].enabled? ? 'on' : 'off'],
           ['Platform',     RUBY_PLATFORM],
           ['Ruby',         RUBY_VERSION],
           ['Uptime',       Formatters::SystemInfo.format_uptime(ctx[:uptime])]]
        end
      end

      # Board > Bulletins: the logon bulletin, the events, the network and
      # the Markdown ones.
      module Bulletins
        def self.configure(w)
          w.accent Accent::STYLES[:board]
          w.maximizable true
          w.title         Icon.title(:board, 'Bulletins')
          w.list_width    30
          w.items         { |_ctx| Formatters::Bulletins::LIST }
          w.item_label    { |b, _ctx| b[:label] }
          w.render_detail { |b, width, ctx| lines(b, width, ctx) }
        end

        def self.lines(bulletin, width, ctx)
          case bulletin[:kind]
          when :logon   then logon(ctx)
          when :events  then events(ctx)
          when :network then Formatters::Network.body(ctx[:network].all).map { |l| l == :spacer ? '' : l }
          when :file
            BBS::Markdown.to_lines(ctx[:bulletins].read(bulletin[:file]).to_s, width: width - 1, theme: ctx[:app].theme)
          end
        end

        def self.logon(ctx)
          Formatters::Bulletin.body(**ctx[:bbs].bulletin(ctx[:username], registered: ctx[:authenticated])).map do |l|
            next l[:text] if l.is_a?(Hash)

            l == :spacer ? '' : " #{l}"
          end
        end

        def self.events(ctx)
          events = ctx[:site].upcoming_events(10)
          events.empty? ? ['  (nothing scheduled)'] : events.map { |e| Formatters::Events.line(e) }
        end
      end

      # Board > Dev Log: what the team pushed, tagged and released.
      module DevLog
        def self.configure(w)
          w.accent Accent::STYLES[:board]
          w.maximizable true
          w.title         Icon.title(:board, 'Dev Log — git.teletypegames.org')
          w.list_width    36
          w.empty_message '  (no activity, or Gitea did not answer)'
          w.items         { |ctx| ctx[:dev_log].recent(60) }
          w.item_label    { |activity, _ctx| Formatters::DevLog.label(activity) }
          w.render_detail { |activity, width, ctx| detail(activity, width, ctx[:dev_log]) }
          w.bottom_meta { |_activity, _ctx| '· push   ◆ tag   ★ release   + repository' }
        end

        def self.detail(activity, width, log)
          Formatters::DevLog.detail(activity, width, commit_url:  ->(sha) { log.commit_url(activity, sha) },
                                                     release_url: log.release_url(activity),
                                                     repo_url:    log.repo_url(activity))
        end
      end
    end
  end
end
