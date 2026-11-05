# frozen_string_literal: true

# View helpers of the classic BBS parts: the logon and logoff screens,
# nodes, mail, the voting booth, bulletins and the hall of
# fame. Like formatters.rb: data and a width in, lines out.
module UI
  module Modern
    module Formatters
      Y = "\e[1;33m"
      C = "\e[1;36m"
      W = "\e[1;37m"
      D = "\e[0;37m"
      K = "\e[1;30m"
      G = "\e[1;32m"
      R = "\e[1;31m"
      M = "\e[1;35m"
      O = "\e[0m"

      def self.bar(value, max, width)
        filled = max.positive? ? (value.to_f / max * width).round : 0
        "#{C}#{'█' * filled}#{K}#{'░' * (width - filled)}#{O}"
      end

      def self.number(n) = n.to_i.to_s.reverse.scan(/\d{1,3}/).join(',').reverse

      def self.duration(seconds)
        seconds = seconds.to_i
        return "#{seconds}s" if seconds < 60
        return "#{seconds / 60}m" if seconds < 3600

        "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
      end

      def self.wrap(text, width) = BBS::FrameBuffer.wrap_ansi(text.to_s, [width, 10].max)

      module Taglines
        # A quote of TaglineService, [text, who].
        def self.line(quote)
          text, who = quote
          "\"#{text}\"#{" — #{who}" if who}"
        end
      end

      module Nodes
        def self.body(nodes, me)
          return ['  (no one on the lines)'] if nodes.empty?

          header = "  #{K}Node  User                  Doing                         On for#{O}"
          rows = nodes.map do |n|
            name = n.name.to_s[0, 20].ljust(21)
            mark = n.session_id == me ? "#{G}◄#{O}" : ' '
            "  #{Y}#{n.number.to_s.rjust(3)}#{O}   #{W}#{name}#{O} #{C}#{n.activity.to_s[0, 29].ljust(29)}#{O} " \
              "#{D}#{Formatters.duration(Time.now - n.since).rjust(6)}#{O} #{mark}"
          end
          [header, "  #{K}#{'─' * 66}#{O}", *rows]
        end
      end

      module UserList
        def self.body(rows)
          return ['  (nobody has registered yet)'] if rows.empty?

          header = "    #{K}User                 Calls  Last call         From#{O}"
          list = rows.map do |name, stats, location, online|
            last = stats ? stats.last_call.localtime.strftime('%Y-%m-%d %H:%M') : '—'
            dot  = online ? "#{G}●#{O}" : ' '
            "  #{dot} #{W}#{name.to_s[0, 20].ljust(21)}#{O}#{Y}#{(stats&.calls || 0).to_s.rjust(5)}#{O}  " \
              "#{D}#{last.ljust(16)}#{O}  #{C}#{location.to_s[0, 18]}#{O}"
          end
          [header, "  #{K}#{'─' * 66}#{O}", *list, :spacer, "  #{G}●#{O} #{D}on line now#{O}"]
        end
      end

      module MyStats
        def self.body(name:, registered:, stats:, node:, caller_number:, posts:, ballots:, letters:, member_since:)
          rows = [
            ['Name',        registered ? "#{name} (registered)" : "#{name} (guest)"],
            ['This call',   "caller ##{Formatters.number(caller_number)}#{", node #{node.number}" if node}"],
            ['Calls',       stats ? stats.calls.to_s : 'this is your first'],
            ['First call',  stats ? stats.first_call.localtime.strftime('%Y-%m-%d %H:%M') : '—'],
            ['Last call',   stats ? stats.last_call.localtime.strftime('%Y-%m-%d %H:%M') : '—'],
            ['Time online', stats ? Formatters.duration(stats.seconds) : '—'],
            ['Posts',       posts.to_s],
            ['Votes',       ballots.to_s],
            ['Mail',        letters.nil? ? 'register to get mail' : "#{letters} letter#{'s' if letters != 1}"]
          ]
          rows << ['Member since', member_since.to_s[0, 10]] if member_since
          [{ kv: rows, label_width: 14 }]
        end
      end

      module Mail
        def self.label(letter)
          mark = letter.read? ? ' ' : '•'
          "#{mark} #{letter.time.localtime.strftime('%m-%d')} #{letter.from.to_s[0, 12].ljust(12)} #{letter.subject}"
        end

        def self.detail(letter, width)
          [
            "  #{K}From:#{O}    #{Y}#{letter.from}#{O}",
            "  #{K}To:#{O}      #{W}#{letter.to}#{O}",
            "  #{K}Date:#{O}    #{D}#{letter.time.localtime.strftime('%Y-%m-%d %H:%M')}#{O}",
            "  #{K}Subject:#{O} #{C}#{letter.subject}#{O}",
            "  #{K}#{'─' * [width - 5, 1].max}#{O}",
            *letter.body.to_s.split("\n").flat_map { |l|
              if l.strip.empty?
                ['']
              else
                Formatters.wrap(l, width - 4).map { |w|
                  "  #{w}"
                }
              end
            }
          ]
        end

        def self.empty(registered)
          registered ? '  (your mailbox is empty)' : '  (register your name to get mail — You > Register…)'
        end
      end

      module Voting
        def self.label(poll, voted)
          "#{voted ? '✓' : '•'} #{poll.title}"
        end

        def self.detail(poll, results, total, ballot, width)
          lines = Formatters.wrap(poll.question, width - 4).map { |l| "  #{W}#{l}#{O}" }
          lines << "  #{D}#{total} vote#{'s' if total != 1}#{ballot ? " · yours: #{ballot}" : ' · you have not voted yet'}#{O}"
          lines << ''
          lines.concat(rows(results, total, ballot, width))
          lines << ''
          lines << "  #{D}Enter or Vote, then the number of your choice.#{O}"
        end

        def self.rows(results, total, ballot, width)
          max   = results.map(&:last).max || 0
          bar_w = width < 60 ? 10 : 20
          opt_w = (width - 16 - bar_w).clamp(12, 28)
          results.each_with_index.map do |(option, votes), i|
            pct  = total.positive? ? (votes * 100.0 / total).round : 0
            mine = option == ballot ? "#{G}◄#{O}" : ' '
            "  #{Y}#{(i + 1).to_s.rjust(2)}.#{O} #{option.to_s[0, opt_w].ljust(opt_w)} " \
              "#{Formatters.bar(votes, max, bar_w)} #{W}#{pct.to_s.rjust(3)}%#{O} #{mine}"
          end
        end
      end

      module HallOfFame
        def self.section(title, rows, width, unit)
          lines = ["  #{Y}#{title}#{O}", "  #{K}#{'─' * [width - 5, 10].max}#{O}"]
          if rows.empty?
            lines << "  #{D}(nobody yet)#{O}"
          else
            max   = rows.map(&:last).max
            bar_w = [width - 42, 6].max
            rows.each_with_index do |(name, n), i|
              lines << "  #{W}#{(i + 1).to_s.rjust(2)}.#{O} #{name.to_s[0, 22].ljust(22)} #{Formatters.bar(n, max, bar_w)} " \
                       "#{Y}#{n.to_s.rjust(5)}#{O} #{D}#{unit}#{O}"
            end
          end
          lines + ['']
        end

        def self.body(callers:, posters:, trivia:, width:)
          section('Top callers', callers, width, 'calls') +
            section('Top posters', posters, width, 'posts') +
            section('TTG Trivia high scores', trivia, width, 'pts')
        end
      end

      module Bulletins
        LIST = [
          { label: ' 1  The logon bulletin',      kind: :logon },
          { label: ' 2  About Teletype Games',    kind: :file, file: 'about.md' },
          { label: ' 3  Coming up',               kind: :events },
          { label: ' 4  Board rules',             kind: :file, file: 'rules.md' },
          { label: ' 5  New to BBSes?',           kind: :file, file: 'newcomers.md' },
          { label: ' 6  Our BBS network',         kind: :network }
        ].freeze
      end

      module PageSysop
        def self.text(sysop_online)
          if sysop_online
            'The sysop is on line and heard the bell: look for an answer in Live Chat (F4).'
          else
            'The sysop is not at the keyboard. The page went to the team, but the surest way is a letter: ' \
              'leave one now?'
          end
        end
      end
    end
  end
end
