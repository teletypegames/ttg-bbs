# frozen_string_literal: true

module UI
  module Petscii
    class Board
      # The colours of a bulletin on the C64, in the keys of a BBS::Theme.
      MARKDOWN = { text: LG, text_bright: WH, accent: YE, label: CY, text_dim: GR }.freeze

      BULLETINS = [
        ['The logon bulletin', :logon], ['About Teletype Games', 'about.md'], ['Coming up', :events],
        ['Board rules', 'rules.md'], ['New to BBSes?', 'newcomers_c64.md'], ['Our BBS network', :network]
      ].freeze

      private

      def markdown(text) = BBS::Markdown.to_lines(text.to_s, width: WIDTH, theme: MARKDOWN).map { |l| " #{l}" }

      def urls(*list) = list.compact.flat_map { |u| u.scan(/.{1,37}/).map { |w| " #{CY}#{w}#{LG}" } }

      # ── bulletins, the network, dev log ───────────────────────────────────────

      def events(count)
        coming = @bbs.site.upcoming_events(count)
        return [" #{GR}(nothing scheduled)#{LG}"] if coming.empty?

        coming.map { |e| " #{GR}#{e.date.strftime('%Y-%m-%d')}#{LG} #{e.name}" }
      end

      def bulletins
        loop do
          doing('Bulletins')
          bulletin = @screen.pick('BULLETINS', BULLETINS, &:first)
          return unless bulletin

          @screen.page(bulletin.first.upcase, bulletin_lines(bulletin.last))
        end
      end

      def bulletin_lines(kind)
        case kind
        when :logon   then logon_bulletin
        when :events  then events(10)
        when :network then network_lines
        else markdown(File.read(File.join(TeletypeBBS::BULLETINS_DIR, kind)))
        end
      end

      def logon_bulletin
        b = @bbs.bulletin(name, registered: registered?)
        [" #{GR}online now#{LG} #{b[:online_count]}  #{GR}messages#{LG} #{b[:total_messages]}", '',
         " #{WH}new on the boards#{LG}", *b[:posts].map { |bd, m| post_line(bd, m) }, '',
         " #{WH}coming up#{LG}", *events(2), '',
         " #{WH}last callers#{LG}", *b[:recent_callers].map { |c|
                                      " #{c.username} #{GR}#{c.timestamp[5, 11].sub('T', ' ')}#{LG}"
                                    },
         '', " #{WH}oneliners#{LG}", *b[:oneliners].map { |o| " #{YE}#{o.username}#{LG}: #{o.text}" }]
      end

      # The BBS Network: where each kind of thing has its board.
      def network
        doing('BBS Network')
        @screen.page('BBS NETWORK', network_lines)
      end

      def network_lines
        lines = @screen.wrap('Each kind of thing has a board of its own; TTG Gate BBS dials them all.', 37).map { |l| " #{l}" }
        @bbs.network.all.each do |board|
          lines += ['', " #{YE}#{board.name}#{LG}", "   #{CY}#{board.address}#{LG}",
                    *@screen.wrap(board.about, 35).map { |l| "   #{l}" }]
        end
        lines + ['', " #{GR}in a browser:#{LG}", " #{CY}bbsweb.teletypegames.org#{LG}",
                 " #{GR}every file on plain http:#{LG}", " #{CY}archive.teletypegames.org#{LG}"]
      end

      # A post in one line: who wrote it, where, and how it starts.
      def post_line(board, message)
        text = message.text.to_s.gsub(/\s+/, ' ')[0, 120]
        " #{YE}#{message.username.to_s[0, 12]}#{LG} #{GR}#{board.title.downcase}#{LG} #{text}"
      end

      def dev_log
        loop do
          doing('Dev Log')
          activity = @screen.pick('DEV LOG', @bbs.dev_log.recent(40), empty: '(no activity, or Gitea did not answer)') do |a|
            "#{GR}#{a.created_at.localtime.strftime('%m-%d')}#{LG} #{a.repo}"
          end
          return unless activity

          @screen.page(activity.repo.upcase[0, 30], dev_log_lines(activity))
        end
      end

      def dev_log_lines(activity)
        what = case activity.kind
               when :push    then "#{activity.user} pushed #{activity.commits.size} to #{activity.ref}"
               when :tag     then "#{activity.user} tagged #{activity.ref}"
               when :release then "#{activity.user} released #{activity.title.empty? ? activity.ref : activity.title}"
               else "#{activity.user}: new or moved repository"
               end
        lines = [" #{WH}#{activity.repo}#{LG}", " #{CY}#{what}#{LG}",
                 " #{GR}#{activity.created_at.localtime.strftime('%Y-%m-%d %H:%M')}#{LG}", '']
        activity.commits.each do |sha, message|
          body = message.lines.grep_v(/\A[\w-]+-By: /).join.strip
          lines += [" #{YE}#{sha[0, 7]}#{LG}", *body.split("\n").map { |l| "  #{l}" }, '']
        end
        lines + urls(@bbs.dev_log.repo_url(activity))
      end
    end
  end
end
