# frozen_string_literal: true

module UI
  class Petscii
    private

    # ── chat ───────────────────────────────────────────────────────────

    def chat_line(line) = "#{GR}#{line.timestamp[0, 5]}#{LG} #{YE}#{line.username}#{LG}: #{line.text}"

    def live_chat
      doing('Live Chat')
      chat.drain(session_id)
      title('LIVE CHAT')
      show_lines(chat.history(12).map { |l| chat_line(l) })
      puts " #{DG}empty line or <-: back#{LG}"
      chat_input("#{CY}>#{LG} ",
                   poll:    -> { chat.drain(session_id).map { |l| chat_line(l) } },
                   on_line: ->(text) { chat.say(name, text, caller_key: caller_key) })
    end

    def show_lines(lines) = lines.each { |line| fit([line]).each { |w| puts w } }

    # A chat line: what +poll+ brings shows up above the line being typed.
    # +on_line+ gets every line sent; an empty line or ← leaves.
    def chat_input(prompt, poll:, on_line:)
      typed = +''
      write prompt
      loop do
        k = key(timeout: 1)
        return puts if k == :escape || (k == :enter && typed.strip.empty?)

        typed = chat_key(k, typed, prompt, poll, on_line)
      end
    end

    def chat_key(k, typed, prompt, poll, on_line)
      case k
      when :idle      then show_chat(poll.call, prompt, typed)
      when :enter     then send_chat(typed, prompt, on_line)
      when :backspace then chat_backspace(typed)
      when String     then chat_type(k, typed, prompt)
      else typed
      end
    end

    def send_chat(typed, prompt, on_line)
      puts
      on_line.call(typed.strip)
      write prompt
      +''
    end

    def show_chat(lines, prompt, typed)
      unless lines.empty?
        write "\r#{' ' * (COLS - 1)}\r"
        show_lines(lines)
        write "#{prompt}#{typed}"
      end
      typed
    end

    def chat_backspace(typed)
      return typed if typed.empty?

      write "\b \b"
      typed.chop
    end

    def chat_type(char, typed, prompt)
      return typed if typed.length >= COLS - 4 - BBS::FrameBuffer.visible_width(prompt)

      write char
      typed + char
    end

    def listen_irc
      doing('IRC')
      irc.subscribe(session_id)
      irc_intro(irc)
      show_lines(irc.history(12).map { |l| irc_line(l) })
      irc.drain(session_id)
      puts " #{DG}any key: back#{LG}"
      show_lines(irc.drain(session_id).map { |l| irc_line(l) }) while key(timeout: 1) == :idle
    end

    def irc_intro(irc)
      title("IRC #{irc.channel}")
      say("Read only: the board listens on #{irc.channel} at Libera.Chat as #{irc.nick}. To talk, " \
          'join from an IRC client: irc.libera.chat 6697.', color: GR)
      status = irc.joined? ? "#{irc.member_count} on the channel" : 'not connected, reconnecting'
      say(status, color: irc.joined? ? GR : RD)
      puts
    end

    def irc_line(line)
      return "#{GR}#{line.timestamp[0, 5]} * #{line.text}#{LG}" if line.username == IrcRelay::SYSTEM

      "#{GR}#{line.timestamp[0, 5]}#{LG} #{CY}<#{line.username}>#{LG} #{line.text}"
    end
  end
end
