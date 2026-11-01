# frozen_string_literal: true

module UI
  module Petscii
    class Board
      # The colours of a bulletin on the C64, in the keys of a BBS::Theme.
      MARKDOWN = { text: LG, text_bright: WH, accent: YE, label: CY, text_dim: GR }.freeze

      BULLETINS = [
        ['The logon bulletin', :logon], ['About Teletype Games', 'about.md'], ['The story so far', :history],
        ['Coming up', :events], ['Board rules', 'rules.md'], ['New to BBSes?', 'newcomers_c64.md'],
        ['Our BBS network', :network]
      ].freeze

      private

      def markdown(text) = BBS::Markdown.to_lines(text.to_s, width: WIDTH, theme: MARKDOWN).map { |l| " #{l}" }

      def urls(*list) = list.compact.flat_map { |u| u.scan(/.{1,37}/).map { |w| " #{CY}#{w}#{LG}" } }

      # ── news, bulletins, dev log ───────────────────────────────────────

      def news
        doing('News')
        lines = [" #{WH}latest releases#{LG}"]
        @bbs.games.latest_releases(5).each { |g| lines += [release_line(g), *urls(@bbs.games.catalog_url(g))] }
        lines += ['', " #{WH}coming up#{LG}", *events(5), '', " #{WH}blog#{LG} #{GR}(ttg blog bbs, 2328)#{LG}"]
        posts = @bbs.site.blog_posts(5)
        lines << " #{GR}(no posts yet)#{LG}" if posts.empty?
        posts.each do |p|
          lines += [" #{GR}#{p.created_at.localtime.strftime('%Y-%m-%d')}#{LG} #{p.title}", *urls(p.url)]
        end
        @screen.page('NEWS', lines)
      end

      def release_line(game)
        " #{YE}#{game.title}#{LG} #{game.version} #{GR}#{game.platform} #{game.released_at&.strftime('%m-%d')}#{LG}"
      end

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
        when :history then history
        when :events  then events(10)
        when :network
          TeletypeBBS::NETWORK.flat_map { |b, address, note| [" #{YE}#{b}#{LG}", "   #{CY}#{address}#{LG}", "   #{note}", ''] }
        else markdown(File.read(File.join(TeletypeBBS::BULLETINS_DIR, kind)))
        end
      end

      def logon_bulletin
        b = @bbs.bulletin(name, registered: registered?)
        [" #{GR}online now#{LG} #{b[:online_count]}  #{GR}messages#{LG} #{b[:total_messages]}", '',
         " #{WH}what's new#{LG}", *b[:releases].map { |g| release_line(g) }, '',
         " #{WH}coming up#{LG}", *events(2), '',
         " #{WH}last callers#{LG}", *b[:recent_callers].map { |c|
                                      " #{c.username} #{GR}#{c.timestamp[5, 11].sub('T', ' ')}#{LG}"
                                    },
         '', " #{WH}oneliners#{LG}", *b[:oneliners].map { |o| " #{YE}#{o.username}#{LG}: #{o.text}" }]
      end

      def history
        list = @bbs.games.release_history
        return [" #{GR}(the catalog did not answer)#{LG}"] if list.empty?

        list.group_by { |_, r| r.released_at.strftime('%Y-%m') }.flat_map do |month, releases|
          [" #{YE}#{Time.strptime(month, '%Y-%m').strftime('%B %Y').downcase}#{LG}",
           *releases.map { |g, r| "  #{GR}#{r.released_at.strftime('%d')}#{LG} #{g.title} #{CY}#{r.version}#{LG}" }, '']
        end
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
