# frozen_string_literal: true

module UI
  class Petscii
    private

    def date(time) = time ? time.localtime.strftime('%Y-%m-%d') : '-'

    # ── callers & users ────────────────────────────────────────────────

    def people
      loop do
        doing('Callers & Users')
        title('CALLERS & USERS')
        puts
        items = [['w', 'who is online', 'the nodes and who is on them'], ['l', 'last callers', 'who called lately'],
                 ['u', 'user listing', 'every registered name'], ['t', 'the team', 'the people of teletype games'],
                 ['q', 'back', 'to the main menu']]
        @people = menu(
          items.map { |k, label, about| Rubbs::Common::Screens::Selector.item(label, key: k, value: k, about: about) },
          index: items.index { |k, _| k == @people },
          back:  'q',
          hint:  'crsr: choose  return: open'
        )
        case @people
        when 'w' then page('WHO IS ONLINE', who_is_online)
        when 'l' then page('LAST CALLERS', last_callers_lines)
        when 'u' then page('USER LISTING', user_listing)
        when 't' then page('THE TEAM', team)
        else return
        end
      end
    end

    def who_is_online
      online.nodes.flat_map do |n|
        me = n.session_id == session_id ? " #{GN}<#{LG}" : ''
        on = Time.now - n.since
        [" #{YE}#{n.number.to_s.rjust(2)}#{LG} #{WH}#{n.name}#{LG}#{me} #{GR}#{(on / 60).to_i}m#{LG}",
         "    #{CY}#{n.activity.to_s[0, 34]}#{LG}"]
      end
    end

    def last_callers_lines
      last_callers.recent(15).map do |c|
        " #{GR}#{c.timestamp.to_s[5, 11].sub('T', ' ')}#{LG} #{YE}#{c.username}#{LG}"
      end
    end

    def user_listing
      rows = board.user_rows
      return [" #{GR}(nobody has registered yet)#{LG}"] if rows.empty?

      [" #{GR}  name                calls last call#{LG}"] +
        rows.map do |user, stats, _location, online|
          " #{online ? "#{GN}*#{LG}" : ' '} #{user[0, 18].ljust(19)}#{YE}#{(stats&.calls || 0).to_s.rjust(5)}#{LG} " \
            "#{GR}#{stats ? stats.last_call.localtime.strftime('%m-%d') : '-'}#{LG}"
        end + ['', " #{GN}*#{LG} #{GR}on line now#{LG}"]
    end

    def team
      members = site.members
      return [" #{GR}(team list unavailable)#{LG}"] if members.empty?

      members.flat_map do |m|
        [" #{YE}#{m.nick}#{LG} #{GR}#{m.real_nick}#{LG}", *wrap(m.motto.gsub(/\s+/, ' '), 36).map { |l| "   #{l}" }, '']
      end
    end

    def fame
      doing('Hall of Fame')
      best = board.hall_of_fame
      lines = [['top callers', best[:callers]],
               ['top posters', best[:posters]], ['ttg trivia high scores', best[:trivia]]]
        .flat_map do |heading, rows|
        [" #{WH}#{heading}#{LG}", *(rows.empty? ? [" #{GR}(nobody yet)#{LG}"] : fame_rows(rows)), '']
      end
      page('HALL OF FAME', lines)
    end

    def fame_rows(rows)
      max = rows.map(&:last).max.to_f
      rows.each_with_index.map do |(who, n), i|
        bar = '█' * (max.positive? ? (n / max * 9).round : 0)
        " #{YE}#{(i + 1).to_s.rjust(2)}#{LG} #{who.to_s[0, 18].ljust(19)}#{CY}#{bar.ljust(9)}#{LG}#{n.to_s.rjust(6)}"
      end
    end

    # ── the voting booth ───────────────────────────────────────────────

    def voting_booth
      loop do
        doing('Voting Booth')
        poll = pick('VOTING BOOTH', voting.polls, empty: '(no polls)') do |p|
          "#{voting.ballot(p, name) ? "#{GN}✓#{LG}" : "#{YE}*#{LG}"} #{p.title}"
        end
        return unless poll

        poll_screen(poll)
      end
    end

    def poll_screen(poll)
      page(poll.title.upcase[0, 30], poll_lines(poll), wait: anonymous?)
      return if anonymous?

      answer = ask("#{WH}your vote#{LG} (1-#{poll.options.size}, return: none): ", max: 3)
      vote(poll, answer) unless answer.empty?
    end

    def poll_lines(poll)
      results = voting.results(poll)
      total   = voting.total(poll)
      ballot  = voting.ballot(poll, name)
      max     = results.map(&:last).max.to_i
      lines = wrap(poll.question).map { |l| " #{WH}#{l}#{LG}" }
      lines << " #{GR}#{total} vote#{'s' if total != 1}#{ballot ? ", yours: #{ballot}" : ', you have not voted yet'}#{LG}"
      lines << ''
      lines + results.each_with_index.map { |(option, votes), i| result_line(i, option, votes, total, max, ballot) }
    end

    def result_line(index, option, votes, total, max, ballot)
      pct  = total.positive? ? (votes * 100.0 / total).round : 0
      bar  = '█' * (max.positive? ? (votes.to_f / max * 6).round : 0)
      mine = option == ballot ? "#{GN}<#{LG}" : ' '
      " #{YE}#{(index + 1).to_s.rjust(2)}#{LG} #{option.to_s[0, 21].ljust(22)}#{CY}#{bar.ljust(6)}#{LG}" \
        "#{pct.to_s.rjust(3)}%#{mine}"
    end

    def vote(poll, answer)
      option = poll.options[answer.to_i - 1] if answer.to_i.positive?
      if option && voting.vote(poll, name, option) == :ok
        say("Your vote: #{option}.", color: GN)
      else
        say("Type a number from 1 to #{poll.options.size}.", color: RD)
      end
      pause('return')
    end

    # ── you ────────────────────────────────────────────────────────────

    def you
      loop do
        doing('Your Stats')
        page("YOU - #{name.upcase}"[0, 30], my_stats, wait: false)
        k = actions(%w[p profile], %w[r register], %w[q back])
        case k
        when 'p' then edit_profile
        when 'r' then register
        else return
        end
      end
    end

    def my_stats
      s = board.my_stats(
        name,
        registered:    registered?,
        session_id:    session_id,
        caller_number: context[:caller_number],
        sysop:         sysop?
      )
      rows = stat_rows(s) + profile_rows
      rows.flat_map { |k, v| wrap("#{GR}#{k.ljust(13)}#{LG}#{v}", 38).map { |l| " #{l}" } }
    end

    def stat_rows(s)
      stats = s[:stats]
      [['name', registered? ? "#{name} (registered)" : "#{name} (guest)"],
       ['this call', "caller ##{s[:caller_number]}#{", node #{s[:node].number}" if s[:node]}"],
       ['calls', stats ? stats.calls.to_s : 'this is your first'],
       ['first call', date(stats&.first_call)], ['last call', date(stats&.last_call)],
       ['posts', s[:posts].to_s], ['votes', s[:ballots].to_s], ['mail', letters(s[:letters])],
       *([['member since', s[:member_since].to_s[0, 10]]] if s[:member_since])]
    end

    def letters(count) = count.nil? ? 'register to get mail' : "#{count} letter#{'s' if count != 1}"

    def profile_rows
      found = registered? ? profile.find(name) : nil
      return [] unless found

      %i[location homepage signature].map { |f| [f.to_s, found[f].to_s] }.reject { |_, v| v.empty? }
    end

    def edit_profile
      unless registered?
        say('Register your name first (R): a profile belongs to a registered name.', color: RD)
        return pause('return')
      end

      title("PROFILE - #{name.upcase}")
      say('Return keeps a field as it is.', color: GR)
      existing = profile.find(name) || {}
      values = %i[signature location homepage notes].to_h { |field| [field, ask_field(field.to_s, existing[field])] }
      profile.update(name, **values)
      say('Profile saved.', color: GN)
      pause('return')
    end

    def ask_field(field, old)
      puts " #{GR}#{field}: #{old}#{LG}" unless old.to_s.empty?
      typed = ask(" #{WH}#{field}#{LG}> ", max: 60)
      typed.empty? ? old.to_s : typed
    end

    def register
      title("REGISTER - #{name.upcase}")
      if registered?
        say("#{name} is already registered and logged in.")
      elsif anonymous?
        say('Call again with a name to register it.', color: RD)
      else
        say('Next time the board asks for this password.', color: GR)
        password = ask(" #{WH}password#{LG}: ", mask: '*')
        confirm  = ask(" #{WH}again#{LG}:    ", mask: '*')
        say(register_result(members.register(name, password, confirm)))
      end
      pause('return')
    end

    def register_result(result)
      unless result.is_a?(Rubbs::Common::Auth::Identity)
        return "#{RD}#{Wording::REGISTER.fetch(result, Wording::REGISTER[:unavailable])}#{LG}"
      end

      session.identity = result
      "#{GN}#{name} is yours now.#{LG}"
    end
  end
end
