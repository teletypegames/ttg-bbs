# frozen_string_literal: true

module UI
  class Petscii
    LETTER_ERRORS = {
      unknown:     'No registered name like that. Write to Sysop, or see C, U.',
      guest:       'A guest writes only to the Sysop. Register to write to others.',
      too_fast:    "One letter every #{MailService::COOLDOWN} seconds, please.",
      daily_limit: 'That is all the feedback a guest can leave today. Register, or call again tomorrow.'
    }.freeze

    private

    # ── message boards ─────────────────────────────────────────────────

    def read_boards
      loop do
        doing('Message Boards')
        board = pick('MESSAGE BOARDS', boards.boards, empty: '(no boards configured)') do |b|
          unread = registered? ? boards.unread(name, b.id) : 0
          unread.positive? ? "#{b.title} #{YE}(#{unread} new)#{LG}" : b.title
        end
        return unless board

        read_board(board)
      end
    end

    def read_board(board)
      loop do
        boards.mark_read(name, board.id) if registered?
        page(board.title.upcase, board_lines(board), wait: false)
        k = actions(['n', 'new post'], %w[r reread], %w[q back])
        return if k == 'q'

        post(board) if k == 'n'
      end
    end

    def board_lines(board)
      messages = boards.messages(board.id, 30).reverse
      return [" #{GR}(no messages on #{board.title} yet)#{LG}"] if messages.empty?

      messages.flat_map do |m|
        ["#{GR}#{m.timestamp.to_s[5, 11]}#{LG} #{YE}#{m.username}#{LG}", *paragraphs(m.text), '']
      end
    end

    # +text+ wrapped to the screen, a space in front of each line.
    def paragraphs(text)
      text.to_s.split("\n").flat_map { |t| t.strip.empty? ? [''] : wrap(t).map { |w| " #{w}" } }
    end

    def post(board)
      title("POST TO #{board.title.upcase}")
      puts " #{GR}from:#{LG} #{name}"
      text = write_text("POST TO #{board.title.upcase}", BoardService::MAX_LENGTH)
      return if text.strip.empty?

      case board.post_message(board, name, text, caller_key: caller_key)
      when :ok       then say('Posted.', color: GN)
      when :too_fast then say("One post every #{BoardService::COOLDOWN} seconds, please.", color: RD)
      else say('Message cannot be empty.', color: RD)
      end
      pause('return')
    end

    # ── mail ───────────────────────────────────────────────────────────

    def read_mail
      doing('Mail')
      return guest_mail unless registered?

      loop do
        case (letter = pick_letter)
        when nil       then return
        when :write    then write_letter
        when :feedback then write_letter(to: MailService::SYSOP)
        else read_letter(letter)
        end
      end
    end

    def guest_mail
      title('E-MAIL')
      say('Mail belongs to registered names (S, then R registers yours). Anyone with a name can leave feedback for the sysop.')
      k = actions(['f', 'feedback to the sysop'], %w[q back])
      write_letter(to: MailService::SYSOP) if k == 'f'
    end

    def pick_letter
      inbox = mail.inbox(name, sysop: sysop?)
      pick("E-MAIL - #{name.upcase}", [:write, :feedback, *inbox], right: "#{inbox.size} ") do |l|
        case l
        when :write    then "#{WH}write a letter#{LG}"
        when :feedback then "#{WH}feedback to the sysop#{LG}"
        else "#{l.read? ? ' ' : "#{YE}*#{LG}"}#{l.time.localtime.strftime('%m-%d')} #{l.from[0, 10].ljust(10)} #{l.subject}"
        end
      end
    end

    def read_letter(letter)
      mail.mark_read(letter)
      page('LETTER', letter_lines(letter), wait: false)
      k = actions(%w[r reply], %w[d delete], %w[q back])
      if k == 'r'
        subject = letter.subject.start_with?('Re: ') ? letter.subject : "Re: #{letter.subject}"
        write_letter(to: letter.from, subject: subject[0, MailService::SUBJECT_MAX])
      elsif k == 'd' && choose("#{WH}delete it? (y/n)#{LG} ", %w[y n], back: 'n') == 'y'
        mail.delete(letter)
      end
    end

    def letter_lines(letter)
      [" #{GR}from#{LG}    #{YE}#{letter.from}#{LG}", " #{GR}to#{LG}      #{letter.to}",
       " #{GR}date#{LG}    #{letter.time.localtime.strftime('%Y-%m-%d %H:%M')}",
       " #{GR}subject#{LG} #{WH}#{letter.subject}#{LG}", "#{DG}#{'─' * 39}#{LG}", *paragraphs(letter.body)]
    end

    def write_letter(to: nil, subject: nil)
      if anonymous?
        say('Call again with a name to write letters.', color: RD)
        return pause('return')
      end

      title('WRITE A LETTER')
      to = ask_recipient(to)
      return if to.empty?

      subject = ask_subject(subject)
      body = write_text('WRITE A LETTER', MailService::BODY_MAX)
      send_letter(to, subject, body) unless body.strip.empty?
    end

    def ask_recipient(to)
      if to
        puts " #{GR}to:#{LG} #{to}"
        return to
      end

      say('To a registered name, or Sysop.', color: GR)
      ask(" #{GR}to:#{LG} ", max: 20)
    end

    def ask_subject(subject)
      if subject
        puts " #{GR}subject:#{LG} #{subject}"
        return subject
      end

      ask(" #{GR}subject:#{LG} ", max: MailService::SUBJECT_MAX)
    end

    def send_letter(to, subject, body)
      result = board.send_letter(name, to, subject, body, registered: registered?, caller_key: caller_key)
      if result == :ok
        say("Your letter is on its way to #{mail.recipient(to)}.", color: GN)
      else
        say(LETTER_ERRORS.fetch(result, 'The letter is empty.'), color: RD)
      end
      pause('return')
    end

    # ── oneliners ──────────────────────────────────────────────────────

    def wall
      loop do
        doing('Oneliners')
        lines = oneliners.recent(15).flat_map do |o|
          wrap("#{YE}#{o.username}#{LG}: #{o.text}", 37).map { |w| " #{w}" }
        end
        page('ONELINERS', lines.empty? ? [" #{GR}(the wall is empty, be the first)#{LG}"] : lines, wait: false)
        return unless actions(%w[w write], %w[q back]) == 'w'

        text = ask(" #{GR}#{OnelinerService::MAX_LENGTH} characters at most#{LG}\r\n> ")
        next if text.empty?

        refused = Wording::ONELINER[oneliners.add(name, text, caller_key: caller_key)]
        next unless refused

        say(refused, color: RD)
        pause('return')
      end
    end

    # ── the sysop's bell ───────────────────────────────────────────────

    def page_sysop
      doing('Paging the Sysop')
      title('PAGING THE SYSOP')
      if context[:paged]
        say('The bell has rung already this call. Leave a letter instead (E).')
        return pause
      end

      context[:paged] = true
      bell
      if board.page_sysop(name)
        say('The sysop is on line and heard the bell: look for an answer in the live chat (L).', color: GN)
        pause
      else
        say('The sysop is not at the keyboard. The page went to the team, but the surest way is a letter.')
        write_letter(to: MailService::SYSOP, subject: 'Page') if
          choose("#{WH}leave a letter now? (y/n)#{LG} ", %w[y n], back: 'n') == 'y'
      end
    end
  end
end
