# frozen_string_literal: true

module UI
  module Petscii
    class Board
      LETTER_ERRORS = {
        unknown:     'No registered name like that. Write to Sysop, or see C, U.',
        guest:       'A guest writes only to the Sysop. Register to write to others.',
        too_fast:    "One letter every #{MailService::COOLDOWN} seconds, please.",
        daily_limit: 'That is all the feedback a guest can leave today. Register, or call again tomorrow.'
      }.freeze

      private

      # ── message boards ─────────────────────────────────────────────────

      def boards
        loop do
          doing('Message Boards')
          board = @screen.pick('MESSAGE BOARDS', @bbs.boards.boards, empty: '(no boards configured)') do |b|
            unread = registered? ? @bbs.boards.unread(name, b.id) : 0
            unread.positive? ? "#{b.title} #{YE}(#{unread} new)#{LG}" : b.title
          end
          return unless board

          read_board(board)
        end
      end

      def read_board(board)
        loop do
          @bbs.boards.mark_read(name, board.id) if registered?
          @screen.page(board.title.upcase, board_lines(board), wait: false)
          k = @screen.actions(['n', 'new post'], %w[r reread], %w[q back])
          return if k == 'q'

          post(board) if k == 'n'
        end
      end

      def board_lines(board)
        messages = @bbs.boards.messages(board.id, 30).reverse
        return [" #{GR}(no messages on #{board.title} yet)#{LG}"] if messages.empty?

        messages.flat_map do |m|
          ["#{GR}#{m.timestamp.to_s[5, 11]}#{LG} #{YE}#{m.username}#{LG}", *paragraphs(m.text), '']
        end
      end

      # +text+ wrapped to the screen, a space in front of each line.
      def paragraphs(text)
        text.to_s.split("\n").flat_map { |t| t.strip.empty? ? [''] : @screen.wrap(t).map { |w| " #{w}" } }
      end

      def post(board)
        @screen.title("POST TO #{board.title.upcase}")
        @screen.puts " #{GR}from:#{LG} #{name}"
        text = @screen.editor(BoardService::MAX_LENGTH, "POST TO #{board.title.upcase}")
        return if text.strip.empty?

        case @bbs.post_message(board, name, text, caller_key: caller_key)
        when :ok       then @screen.say('Posted.', GN)
        when :too_fast then @screen.say("One post every #{BoardService::COOLDOWN} seconds, please.", RD)
        else @screen.say('Message cannot be empty.', RD)
        end
        @screen.pause('return')
      end

      # ── mail ───────────────────────────────────────────────────────────

      def mail
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
        @screen.title('E-MAIL')
        @screen.say('Mail belongs to registered names (S, then R registers yours). Anyone with a name can ' \
                    'leave feedback for the sysop.')
        k = @screen.actions(['f', 'feedback to the sysop'], %w[q back])
        write_letter(to: MailService::SYSOP) if k == 'f'
      end

      def pick_letter
        inbox = @bbs.mail.inbox(name, sysop: sysop?)
        @screen.pick("E-MAIL - #{name.upcase}", [:write, :feedback, *inbox], right: "#{inbox.size} ") do |l|
          case l
          when :write    then "#{WH}write a letter#{LG}"
          when :feedback then "#{WH}feedback to the sysop#{LG}"
          else "#{l.read? ? ' ' : "#{YE}*#{LG}"}#{l.time.localtime.strftime('%m-%d')} #{l.from[0, 10].ljust(10)} #{l.subject}"
          end
        end
      end

      def read_letter(letter)
        @bbs.mail.mark_read(letter)
        @screen.page('LETTER', letter_lines(letter), wait: false)
        k = @screen.actions(%w[r reply], %w[d delete], %w[q back])
        if k == 'r'
          subject = letter.subject.start_with?('Re: ') ? letter.subject : "Re: #{letter.subject}"
          write_letter(to: letter.from, subject: subject[0, MailService::SUBJECT_MAX])
        elsif k == 'd' && @screen.choose("#{WH}delete it? (y/n)#{LG} ", %w[y n], back: 'n') == 'y'
          @bbs.mail.delete(letter)
        end
      end

      def letter_lines(letter)
        [" #{GR}from#{LG}    #{YE}#{letter.from}#{LG}", " #{GR}to#{LG}      #{letter.to}",
         " #{GR}date#{LG}    #{letter.time.localtime.strftime('%Y-%m-%d %H:%M')}",
         " #{GR}subject#{LG} #{WH}#{letter.subject}#{LG}", "#{DG}#{'─' * 39}#{LG}", *paragraphs(letter.body)]
      end

      def write_letter(to: nil, subject: nil)
        if anonymous?
          @screen.say('Call again with a name to write letters.', RD)
          return @screen.pause('return')
        end

        @screen.title('WRITE A LETTER')
        to = ask_recipient(to)
        return if to.empty?

        subject = ask_subject(subject)
        body = @screen.editor(MailService::BODY_MAX, 'WRITE A LETTER')
        send_letter(to, subject, body) unless body.strip.empty?
      end

      def ask_recipient(to)
        if to
          @screen.puts " #{GR}to:#{LG} #{to}"
          return to
        end

        @screen.say('To a registered name, or Sysop.', GR)
        @screen.ask(" #{GR}to:#{LG} ", max: 20)
      end

      def ask_subject(subject)
        if subject
          @screen.puts " #{GR}subject:#{LG} #{subject}"
          return subject
        end

        @screen.ask(" #{GR}subject:#{LG} ", max: MailService::SUBJECT_MAX)
      end

      def send_letter(to, subject, body)
        result = @bbs.send_letter(name, to, subject, body, registered: registered?, caller_key: caller_key)
        if result == :ok
          @screen.say("Your letter is on its way to #{@bbs.mail.recipient(to)}.", GN)
        else
          @screen.say(LETTER_ERRORS.fetch(result, 'The letter is empty.'), RD)
        end
        @screen.pause('return')
      end

      # ── oneliners ──────────────────────────────────────────────────────

      def oneliners
        loop do
          doing('Oneliners')
          lines = @bbs.oneliners.recent(15).flat_map do |o|
            @screen.wrap("#{YE}#{o.username}#{LG}: #{o.text}", 37).map { |w| " #{w}" }
          end
          @screen.page('ONELINERS', lines.empty? ? [" #{GR}(the wall is empty, be the first)#{LG}"] : lines, wait: false)
          return unless @screen.actions(%w[w write], %w[q back]) == 'w'

          text = @screen.ask(" #{GR}#{OnelinerService::MAX_LENGTH} characters at most#{LG}\r\n> ")
          next if text.empty?

          refused = Wording::ONELINER[@bbs.oneliners.add(name, text, caller_key: caller_key)]
          next unless refused

          @screen.say(refused, RD)
          @screen.pause('return')
        end
      end

      # ── chat ───────────────────────────────────────────────────────────

      def chat_line(line) = "#{GR}#{line.timestamp[0, 5]}#{LG} #{YE}#{line.username}#{LG}: #{line.text}"

      def live_chat
        doing('Live Chat')
        @bbs.chat.drain(session_id)
        @screen.title('LIVE CHAT')
        show_lines(@bbs.chat.history(12).map { |l| chat_line(l) })
        @screen.puts " #{DG}empty line or <-: back#{LG}"
        @screen.chat("#{CY}>#{LG} ",
                     poll:    -> { @bbs.chat.drain(session_id).map { |l| chat_line(l) } },
                     on_line: ->(text) { @bbs.chat.say(name, text, caller_key: caller_key) })
      end

      def show_lines(lines) = lines.each { |line| @screen.fit([line]).each { |w| @screen.puts w } }

      def irc
        doing('IRC')
        irc = @bbs.irc
        irc.subscribe(session_id)
        irc_intro(irc)
        show_lines(irc.history(12).map { |l| irc_line(l) })
        irc.drain(session_id)
        @screen.puts " #{DG}any key: back#{LG}"
        show_lines(irc.drain(session_id).map { |l| irc_line(l) }) while @screen.key(timeout: 1) == :idle
      end

      def irc_intro(irc)
        @screen.title("IRC #{irc.channel}")
        @screen.say("Read only: the board listens on #{irc.channel} at Libera.Chat as #{irc.nick}. To talk, " \
                    'join from an IRC client: irc.libera.chat 6697.', GR)
        status = irc.joined? ? "#{irc.member_count} on the channel" : 'not connected, reconnecting'
        @screen.say(status, irc.joined? ? GR : RD)
        @screen.puts
      end

      def irc_line(line)
        return "#{GR}#{line.timestamp[0, 5]} * #{line.text}#{LG}" if line.username == IrcRelay::SYSTEM

        "#{GR}#{line.timestamp[0, 5]}#{LG} #{CY}<#{line.username}>#{LG} #{line.text}"
      end

      # ── the sysop's bell ───────────────────────────────────────────────

      def page_sysop
        doing('Paging the Sysop')
        @screen.title('PAGING THE SYSOP')
        if @ctx[:paged]
          @screen.say('The bell has rung already this call. Leave a letter instead (E).')
          return @screen.pause
        end

        @ctx[:paged] = true
        @screen.bell
        if @bbs.page_sysop(name)
          @screen.say('The sysop is on line and heard the bell: look for an answer in the live chat (L).', GN)
          @screen.pause
        else
          @screen.say('The sysop is not at the keyboard. The page went to the team, but the surest way is a ' \
                      'letter.')
          write_letter(to: MailService::SYSOP, subject: 'Page') if
            @screen.choose("#{WH}leave a letter now? (y/n)#{LG} ", %w[y n], back: 'n') == 'y'
        end
      end
    end
  end
end
