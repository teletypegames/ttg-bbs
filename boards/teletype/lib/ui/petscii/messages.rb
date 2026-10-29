# frozen_string_literal: true

module UI
  module Petscii
    class Board
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
          messages = @bbs.boards.messages(board.id, 30).reverse
          lines = messages.flat_map do |m|
            ["#{GR}#{m.timestamp.to_s[5, 11]}#{LG} #{YE}#{m.username}#{LG}",
             *m.text.to_s.split("\n").flat_map { |t| t.strip.empty? ? [''] : @screen.wrap(t).map { |w| " #{w}" } }, '']
          end
          lines = [" #{GR}(no messages on #{board.title} yet)#{LG}"] if messages.empty?
          @screen.page(board.title.upcase, lines, wait: false)
          k = @screen.choose("#{YE}N#{LG}ew post  #{YE}R#{LG}eread  #{YE}Q#{LG}: back ", %w[n r q])
          return if k == 'q'

          post(board) if k == 'n'
        end
      end

      def post(board)
        @screen.title("POST TO #{board.title.upcase}")
        @screen.puts " #{GR}from:#{LG} #{name}"
        text = @screen.editor(1000)
        return if text.strip.empty?

        case @bbs.post_message(board, name, text, session_id: session_id)
        when :ok       then @screen.say('Posted.', GN)
        when :too_fast then @screen.say("One post every #{BoardService::COOLDOWN} seconds, please.", RD)
        else @screen.say('Message cannot be empty.', RD)
        end
        @screen.pause('return')
      end

      # ── mail ───────────────────────────────────────────────────────────

      def mail
        doing('Mail')
        unless registered?
          @screen.title('E-MAIL')
          @screen.say('Mail belongs to registered names (S, then R registers yours). Anyone with a name can ' \
                      'leave feedback for the sysop.')
          k = @screen.choose("#{YE}F#{LG}eedback to the sysop  #{YE}Q#{LG}: back ", %w[f q])
          write_letter(to: MailService::SYSOP) if k == 'f'
          return
        end

        loop do
          inbox  = @bbs.mail.inbox(name, sysop: sysop?)
          letter = @screen.pick("E-MAIL - #{name.upcase}", [:write, :feedback, *inbox], right: "#{inbox.size} ") do |l|
            case l
            when :write    then "#{WH}write a letter#{LG}"
            when :feedback then "#{WH}feedback to the sysop#{LG}"
            else "#{l.read? ? ' ' : "#{YE}*#{LG}"}#{l.time.localtime.strftime('%m-%d')} #{l.from[0, 10].ljust(10)} #{l.subject}"
            end
          end
          case letter
          when nil       then return
          when :write    then write_letter
          when :feedback then write_letter(to: MailService::SYSOP)
          else read_letter(letter)
          end
        end
      end

      def read_letter(letter)
        @bbs.mail.mark_read(letter)
        lines = [" #{GR}from#{LG}    #{YE}#{letter.from}#{LG}", " #{GR}to#{LG}      #{letter.to}",
                 " #{GR}date#{LG}    #{letter.time.localtime.strftime('%Y-%m-%d %H:%M')}",
                 " #{GR}subject#{LG} #{WH}#{letter.subject}#{LG}", "#{DG}#{'─' * 39}#{LG}",
                 *letter.body.to_s.split("\n").flat_map { |l| l.strip.empty? ? [''] : @screen.wrap(l).map { |w| " #{w}" } }]
        @screen.page('LETTER', lines, wait: false)
        k = @screen.choose("#{YE}R#{LG}eply  #{YE}D#{LG}elete  #{YE}Q#{LG}: back ", %w[r d q])
        if k == 'r'
          subject = letter.subject.start_with?('Re: ') ? letter.subject : "Re: #{letter.subject}"
          write_letter(to: letter.from, subject: subject[0, MailService::SUBJECT_MAX])
        elsif k == 'd' && @screen.choose("#{WH}delete it? (y/n)#{LG} ", %w[y n], back: 'n') == 'y'
          @bbs.mail.delete(letter)
        end
      end

      def write_letter(to: nil, subject: nil)
        if anonymous?
          @screen.say('Call again with a name to write letters.', RD)
          return @screen.pause('return')
        end

        @screen.title('WRITE A LETTER')
        if to
          @screen.puts " #{GR}to:#{LG} #{to}"
        else
          @screen.say('To a registered name, or Sysop.', GR)
          to = @screen.ask(" #{GR}to:#{LG} ", max: 20)
          return if to.empty?
        end
        if subject
          @screen.puts " #{GR}subject:#{LG} #{subject}"
        else
          subject = @screen.ask(" #{GR}subject:#{LG} ", max: MailService::SUBJECT_MAX)
        end
        body = @screen.editor(MailService::BODY_MAX)
        return if body.strip.empty?

        case @bbs.send_letter(name, to, subject, body, registered: registered?, session_id: session_id)
        when :ok       then @screen.say("Your letter is on its way to #{@bbs.mail.recipient(to)}.", GN)
        when :unknown  then @screen.say('No registered name like that. Write to Sysop, or see C, U.', RD)
        when :guest    then @screen.say('A guest writes only to the Sysop. Register to write to others.', RD)
        when :too_fast then @screen.say("One letter every #{MailService::COOLDOWN} seconds, please.", RD)
        else @screen.say('The letter is empty.', RD)
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
          return unless @screen.choose("#{YE}W#{LG}rite  #{YE}Q#{LG}: back ", %w[w q]) == 'w'

          text = @screen.ask(" #{GR}#{OnelinerService::MAX_LENGTH} characters at most#{LG}\r\n> ")
          next if text.empty?

          case @bbs.oneliners.add(name, text)
          when :anonymous
            @screen.say('Call again with a name to write on the wall.', RD)
            @screen.pause('return')
          when :too_long
            @screen.say("At most #{OnelinerService::MAX_LENGTH} characters.", RD)
            @screen.pause('return')
          end
        end
      end

      # ── chat ───────────────────────────────────────────────────────────

      def chat_line(line) = "#{GR}#{line.timestamp[0, 5]}#{LG} #{YE}#{line.username}#{LG}: #{line.text}"

      def live_chat
        doing('Live Chat')
        @bbs.chat.drain(session_id)
        @screen.title('LIVE CHAT')
        @bbs.chat.history(12).each { |l| @screen.fit([chat_line(l)]).each { |w| @screen.puts w } }
        @screen.puts " #{DG}empty line or <-: back#{LG}"
        @screen.chat("#{CY}>#{LG} ",
                     poll:    -> { @bbs.chat.drain(session_id).map { |l| chat_line(l) } },
                     on_line: lambda { |text|
                       @bbs.chat.broadcast(name, text) if @bbs.chat.may_speak?(session_id)
                     })
      end

      def irc
        doing('IRC')
        irc = @bbs.irc
        irc.subscribe(session_id)
        @screen.title("IRC #{irc.channel}")
        @screen.say("Read only: the board listens on #{irc.channel} at Libera.Chat as #{irc.nick}. To talk, " \
                    'join from an IRC client: irc.libera.chat 6697.', GR)
        status = irc.joined? ? "#{irc.member_count} on the channel" : 'not connected, reconnecting'
        @screen.say(status, irc.joined? ? GR : RD)
        @screen.puts
        irc.history(12).each { |l| @screen.fit([irc_line(l)]).each { |w| @screen.puts w } }
        irc.drain(session_id)
        @screen.puts " #{DG}any key: back#{LG}"
        loop do
          k = @screen.key(timeout: 1)
          return unless k == :idle

          irc.drain(session_id).each { |l| @screen.fit([irc_line(l)]).each { |w| @screen.puts w } }
        end
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
