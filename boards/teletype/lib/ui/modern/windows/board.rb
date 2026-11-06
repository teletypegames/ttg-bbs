# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # Board > System Info, Bulletins and Dev Log.
      module Board
        extend Section

        section :board do
          # The board in numbers.
          window :system_info, :info do
            title 'System Info'
            width 60
            height 12
            body { [{ kv: system_rows, label_width: 15 }] }
          end

          # The logon bulletin, the events, the network and the Markdown ones.
          window :bulletins, :master_detail do
            title 'Bulletins'
            list_width 30
            items { Formatters::Bulletins::LIST }
            label { |b| b[:label] }
            detail { |b, width| bulletin_lines(b, width) }
          end

          # What the team pushed, tagged and released.
          window :dev_log, :master_detail do
            title 'Dev Log — git.teletypegames.org'
            list_width 36
            empty '  (no activity, or Gitea did not answer)'
            items { dev_log.recent(60) }
            label { |activity| Formatters::DevLog.label(activity) }
            detail { |activity, width| dev_log_detail(activity, width) }
            meta { '· push   ◆ tag   ★ release   + repository' }
          end
        end

        helpers do
          def system_rows
            [['Nodes in use', online.count.to_s],
             ['Calls',        "#{last_callers.total_calls} (#{last_callers.calls_today} today)"],
             ['Wiki',         'https://wiki.teletypegames.org'],
             ['Games API',    'https://teletypegames.org'],
             ['Platform',     RUBY_PLATFORM],
             ['Ruby',         RUBY_VERSION],
             ['Uptime',       Formatters::SystemInfo.format_uptime(TeletypeBBS::STARTED_AT)]]
          end

          def bulletin_lines(bulletin, width)
            case bulletin[:kind]
            when :logon   then logon_bulletin
            when :events  then upcoming_events
            when :network then Formatters::Network.body(network.all).map { |l| l == :spacer ? '' : l }
            when :file    then markdown(bulletins.read(bulletin[:file]).to_s, width - 1)
            end
          end

          def logon_bulletin
            Formatters::Bulletin.body(**board.bulletin(caller_name, registered: registered?)).map do |l|
              next l[:text] if l.is_a?(Hash)

              l == :spacer ? '' : " #{l}"
            end
          end

          def upcoming_events
            events = site.upcoming_events(10)
            events.empty? ? ['  (nothing scheduled)'] : events.map { |e| Formatters::Events.line(e) }
          end

          def dev_log_detail(activity, width)
            Formatters::DevLog.detail(
              activity,
              width,
              commit_url:  ->(sha) { dev_log.commit_url(activity, sha) },
              release_url: dev_log.release_url(activity),
              repo_url:    dev_log.repo_url(activity)
            )
          end
        end
      end
    end
  end
end
