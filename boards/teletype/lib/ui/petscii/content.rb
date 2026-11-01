# frozen_string_literal: true

module UI
  module Petscii
    class Board
      # The colours of a wiki page on the C64, in the keys of a BBS::Theme.
      MARKDOWN = { text: LG, text_bright: WH, accent: YE, label: CY, text_dim: GR }.freeze

      BULLETINS = [
        ['The logon bulletin', :logon], ['About Teletype Games', :about], ['The story so far', :history],
        ['Coming up', :events], ['Board rules', 'rules.md'], ['New to BBSes?', 'newcomers_c64.md'],
        ['Our BBS network', :network]
      ].freeze

      private

      def markdown(text) = BBS::Markdown.to_lines(text.to_s, width: WIDTH, theme: MARKDOWN).map { |l| " #{l}" }

      def urls(*list) = list.compact.flat_map { |u| u.scan(/.{1,37}/).map { |w| " #{CY}#{w}#{LG}" } }

      # ── file areas ─────────────────────────────────────────────────────

      def file_areas
        loop do
          doing('File Areas')
          area = @screen.pick('FILE AREAS', @bbs.file_areas.areas,
                              empty: '(the catalog or the FTP server did not answer, try again later)') do |a|
            "#{a.title[0, 24].ljust(25)}#{GR}#{a.files.size.to_s.rjust(3)} files#{LG}"
          end
          return unless area

          loop do
            item = @screen.pick("FILES - #{area.title.upcase}", area.files) do |f|
              "#{@bbs.file_areas.new?(f) ? "#{YE}*#{LG}" : ' '}#{f.name[0, 22].ljust(23)}#{GR}#{size(f.bytes)}#{LG}"
            end
            break unless item

            file_card(item)
          end
        end
      end

      def file_card(item)
        g = item.game
        lines = [" #{WH}#{item.name}#{LG}", " #{GR}#{size(item.bytes)} #{item.date&.strftime('%Y-%m-%d')} " \
                                            "#{item.downloads} dls#{LG}", '',
                 "#{CY}┌#{'─' * 36}┐#{LG}",
                 *[g.title, "v#{g.version} #{GamesService.platform_name(g.platform)}", ''].map { |l| diz_line(l) },
                 *@screen.wrap(g.desc, 34).first(6).map { |l| diz_line(l) },
                 "#{CY}└#{'─' * 36}┘#{LG}", '',
                 " #{GR}fetch it from:#{LG}", *urls(@bbs.files.http_url(item.path), @bbs.files.url(item.path)), '',
                 " #{GR}play or read about it:#{LG}", *urls(@bbs.games.catalog_url(g))]
        @screen.page(item.name.upcase, lines)
      end

      def diz_line(text) = "#{CY}│#{WH} #{text.to_s[0, 34].ljust(35)}#{CY}│#{LG}"

      def size(bytes)
        return "#{bytes}b" if bytes < 1024
        return "#{(bytes / 1024.0).round}k" if bytes < 1024 * 1024

        format('%.1fm', bytes / 1024.0 / 1024)
      end

      # ── the ftp server ─────────────────────────────────────────────────

      def ftp
        path = @ctx[:ftp_path] || FileLibraryService::ROOT
        loop do
          doing('FTP Browser')
          entries = @bbs.files.list(path)
          if entries.nil?
            @screen.title('FTP')
            @screen.say("The FTP server did not answer for #{path}. Try again later.", RD)
            return @screen.pause
          end
          @ctx[:ftp_path] = path
          up    = path == FileLibraryService::ROOT ? [] : [FtpEntry.new(name: '..', path: @bbs.files.parent(path), dir: true)]
          entry = @screen.pick("FTP #{path}"[0, 30], up + entries) do |e|
            e.dir ? "#{YE}#{e.name}/#{LG}" : "#{e.name[0, 24].ljust(25)}#{GR}#{size(e.bytes)}#{LG}"
          end
          return unless entry

          entry.dir ? path = entry.path : ftp_file(entry)
        end
      end

      def ftp_file(entry)
        lines = [" #{WH}#{entry.name}#{LG}", " #{GR}#{size(entry.bytes)} #{entry.modified&.strftime('%Y-%m-%d %H:%M')}#{LG}",
                 '', " #{GR}fetch it from:#{LG}", *urls(@bbs.files.http_url(entry.path), @bbs.files.url(entry.path))]
        text = @bbs.files.preview(entry)
        unless text.strip.empty?
          lines += ['', "#{DG}#{'─' * 39}#{LG}"]
          lines += if entry.name.match?(/\.md\z/i)
                     markdown(text)
                   else
                     text.delete("\r").split("\n").map { |l| l.gsub("\t", '  ').gsub(/[\x00-\x1f\x7f]/, '') }
                   end
        end
        @screen.page(entry.name.upcase[0, 30], lines)
      end

      # ── the game catalog ───────────────────────────────────────────────

      def games
        loop do
          doing('Game Catalog')
          platform = @screen.pick('GAME CATALOG', [:all, *@bbs.games.platforms]) do |p|
            p == :all ? "#{WH}every platform#{LG}" : GamesService.platform_name(p)
          end
          return unless platform

          filter = platform == :all ? nil : platform
          loop do
            game = @screen.pick("GAMES - #{filter ? GamesService.platform_name(filter).upcase : 'ALL'}",
                                @bbs.games.by_platform(filter)) do |g|
              filter ? g.title : "#{GR}#{g.platform[0, 7].ljust(8)}#{LG}#{g.title}"
            end
            break unless game

            game_card(game)
          end
        end
      end

      def game_card(game)
        lines = [" #{WH}#{game.title}#{LG}",
                 " #{CY}#{[GamesService.platform_name(game.platform), game.category,
                           game.author].reject(&:empty?).join(', ')}#{LG}"]
        lines << " #{GR}latest: #{game.version} #{game.released_at&.strftime('%Y-%m-%d')}#{LG}" if game.released?
        lines << " #{GR}#{[game.status, game.license, "#{game.downloads} downloads"].reject(&:empty?).join(', ')}#{LG}"
        lines += ['', *urls(@bbs.games.catalog_url(game)), '']
        lines += @screen.wrap(game.desc).map { |l| " #{l}" }
        lines += ['', *@screen.wrap(game.story).map { |l| " #{l}" }] unless game.story.to_s.strip.empty?
        if game.releases.size > 1
          lines += ['', " #{WH}releases#{LG}"]
          game.releases.reverse_each do |r|
            lines << " #{YE}#{r.version[0, 14].ljust(15)}#{LG}#{GR}#{r.released_at&.strftime('%Y-%m-%d')} #{r.downloads} dl#{LG}"
          end
        end
        @screen.page(game.title.upcase[0, 30], lines)
      end

      # ── the wiki ───────────────────────────────────────────────────────

      def wiki
        loop do
          doing('Wiki')
          sections = [*TeletypeBBS::WIKI_SECTIONS.keys, :howtos, :language]
          section = @screen.pick('WIKI & HOW-TOS', sections, right: "#{@ctx[:lang] || 'en'} ") do |s|
            case s
            when :howtos   then 'Tech How-tos'
            when :language then "#{WH}language: #{@ctx[:lang] == 'hu' ? 'magyar' : 'english'}#{LG}"
            else TeletypeBBS::WIKI_SECTIONS[s][:title]
            end
          end
          case section
          when nil       then return
          when :language then @ctx[:lang] = @ctx[:lang] == 'hu' ? 'en' : 'hu'
          when :howtos   then howtos
          else wiki_section(section)
          end
        end
      end

      def wiki_section(section)
        spec = TeletypeBBS::WIKI_SECTIONS[section]
        loop do
          pages = @bbs.wiki.section(spec[:prefix], lang: lang)
          page  = @screen.pick(spec[:title].upcase, pages, empty: '(no pages found)') do |p|
            depth = p.path.count('/') - spec[:prefix].count('/')
            "#{' ' * depth}#{p.title}"
          end
          return unless page

          @screen.page(page.title.upcase[0, 30],
                       markdown(@bbs.wiki.content(page.path, lang: lang)) +
                       ['', *urls(@bbs.wiki.page_url(page.path, lang: lang))])
        end
      end

      def howtos
        loop do
          howto = @screen.pick('TECH HOW-TOS', @bbs.site.howtos, empty: '(the how-to feed did not answer)', &:title)
          return unless howto

          text = @bbs.wiki.content(howto.url.sub(%r{\Ahttps://wiki\.teletypegames\.org/?}, ''))
          text = "# #{howto.title}\n\n#{howto.description}" if text.to_s.strip.empty?
          @screen.page(howto.title.upcase[0, 30], markdown(text) + ['', *urls(howto.url)])
        end
      end

      def lang = @ctx[:lang] || 'en'

      # ── news, bulletins, dev log ───────────────────────────────────────

      def news
        doing('News')
        lines = [" #{WH}latest releases#{LG}"]
        @bbs.games.latest_releases(5).each { |g| lines += [release_line(g), *urls(@bbs.games.catalog_url(g))] }
        lines += ['', " #{WH}coming up#{LG}", *events(5), '', " #{WH}blog#{LG} #{GR}(r: doors > ttg blog)#{LG}"]
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
        when :about   then markdown(@bbs.wiki.content('', lang: lang))
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
