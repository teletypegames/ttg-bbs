# frozen_string_literal: true

require_relative 'chat_service'
require_relative 'tls_connect'

# Listens on one IRC channel for the board under a fixed nick, read only: it
# never speaks there. A background thread keeps the connection (TLS, PING
# when the server is silent, reconnect with a growing pause) and puts every
# channel message into a ChatService hub, so a session subscribes and drains
# it like the Live Chat. With TELETYPE_BBS_IRC_PASSWORD the nick logs in with SASL.
class IrcRelay
  RETRY   = [5, 15, 30, 60, 120, 300].freeze
  IDLE    = 180
  CONNECT_TIMEOUT = 20
  STABLE  = 300
  SYSTEM  = '*'

  attr_reader :server, :port, :channel, :nick, :topic

  def initialize(server:, port:, channel:, nick:, password: nil, hub: ChatService.new)
    @server   = server.to_s
    @port     = Integer(port)
    @channel  = channel
    @nick     = nick
    @password = password.to_s.empty? ? nil : password
    @hub      = hub
    @members  = Set.new
    @mu       = Mutex.new
    @joined   = false
  end

  def enabled? = !@server.empty?

  def start
    @thread ||= Thread.new { run } if enabled?
    self
  end

  def joined?      = @mu.synchronize { @joined }
  def member_count = @mu.synchronize { @members.size }

  def subscribe(session_id)   = @hub.subscribe(session_id)
  def unsubscribe(session_id) = @hub.unsubscribe(session_id)
  def drain(session_id)       = @hub.drain(session_id)
  def history(count = 100)    = @hub.history(count)

  # mIRC formatting (bold, colours, italics…) and every control character
  # out: nothing from the channel reaches a terminal as an escape sequence.
  def self.clean(text)
    plain = text.to_s.gsub(/\x03(\d{1,2}(,\d{1,2})?)?/, '').gsub(/\x04(\h{6}(,\h{6})?)?/, '')
    BBS::Text.clean(plain, keep_newlines: false).tr("\t", ' ').strip
  end

  private

  def run
    failures = 0
    loop do
      started = monotonic
      begin
        connection
      rescue StandardError => e
        warn "IRC: #{e.class}: #{e.message}"
      end
      lost
      failures = monotonic - started > STABLE ? 0 : failures + 1
      sleep RETRY[(failures - 1).clamp(0, RETRY.size - 1)]
    end
  end

  def connection
    @sock = TlsConnect.open(@server, @port, timeout: CONNECT_TIMEOUT)
    @current = @nick
    @pinged  = false
    send_line('CAP REQ :sasl') if @password
    send_line("NICK #{@current}")
    send_line("USER #{@nick} 0 * :Teletype BBS, telnet teletypegames.org 2323")
    while (line = next_line)
      handle(*parse(line))
    end
  ensure
    @sock&.close
    @sock = nil
  end

  def next_line
    loop do
      if @sock.pending.positive? || @sock.to_io.wait_readable(IDLE)
        line = @sock.gets("\n", 8192) or return nil
        @pinged = false
        return line.force_encoding(Encoding::UTF_8).scrub('?').chomp
      end
      raise IOError, 'the server stopped answering' if @pinged

      @pinged = true
      send_line("PING :#{@server}")
    end
  end

  # [nick of the sender, COMMAND, params with the trailing one last]
  def parse(line)
    prefix = nil
    prefix, line = line[1..].split(' ', 2) if line.start_with?(':')
    head, trailing = line.to_s.split(' :', 2)
    params = head.to_s.split
    command = params.shift.to_s.upcase
    params << trailing if trailing
    [prefix.to_s.split('!').first, command, params]
  end

  def handle(from, command, params)
    login_reply(command, params) || channel_event(from, command, params)
  end

  # The replies of the login (SASL, the nick, the welcome); nil for the rest.
  def login_reply(command, params)
    case command
    when 'PING'         then send_line("PONG :#{params.last}")
    when 'CAP'          then cap(params)
    when 'AUTHENTICATE' then send_line("AUTHENTICATE #{["#{@nick}\0#{@nick}\0#{@password}"].pack('m0')}")
    when '903'          then send_line('CAP END')
    when '902', '904', '905', '906', '908' then sasl_failed(command)
    when '001'          then send_line("JOIN #{@channel}")
    when '433'          then retry_nick
    when 'ERROR'        then raise IOError, params.last.to_s
    end
  end

  # What happens on the channel.
  def channel_event(from, command, params)
    return names(params.last) if command == '353'
    return @topic = self.class.clean(params.last) if command == '332'
    return joined(from) if command == 'JOIN'
    return left(from) if command == 'QUIT'
    return renamed(from, params.last) if command == 'NICK'
    return unless here?(params.first)

    channel_message(from, command, params)
  end

  def channel_message(from, command, params)
    case command
    when 'PART'              then left(from)
    when 'KICK'              then kicked(params[1])
    when 'TOPIC'             then new_topic(from, params.last)
    when 'PRIVMSG', 'NOTICE' then said(from, params.last)
    end
  end

  def sasl_failed(command)
    warn "IRC: SASL login failed (#{command})"
    send_line('CAP END')
  end

  def cap(params)
    return unless %w[ACK NAK].include?(params[1])

    if params[1] == 'ACK' && params.last.split.include?('sasl')
      send_line('AUTHENTICATE PLAIN')
    else
      send_line('CAP END')
    end
  end

  # Taken nick at login: ttgbbs_, ttgbbs__… The server keeps nicks to 16.
  def retry_nick
    @current = "#{@current}_"[0, 16]
    send_line("NICK #{@current}")
  end

  def names(list)
    nicks = list.to_s.split.map { |n| n.sub(/\A[~&@%+]+/, '') } - [@current]
    @mu.synchronize { @members.merge(nicks) }
  end

  def joined(from)
    if me?(from)
      @mu.synchronize do
        @joined = true
        @members.clear
      end
      @hub.broadcast(SYSTEM, "Listening on #{@channel} as #{@current}.")
    else
      @mu.synchronize { @members << from }
    end
  end

  def left(from) = @mu.synchronize { @members.delete(from) }

  def kicked(who)
    return left(who) unless me?(who)

    @mu.synchronize { @joined = false }
    send_line("JOIN #{@channel}")
  end

  def renamed(from, to)
    if me?(from)
      @current = to
    else
      @mu.synchronize { @members.delete(from) << to }
    end
  end

  def new_topic(from, text)
    @topic = self.class.clean(text)
    @hub.broadcast(SYSTEM, "#{self.class.clean(from)} set the topic: #{@topic}")
  end

  # CTCP ACTION is /me; the other CTCP queries go unanswered.
  def said(from, text)
    if (action = text[/\A\x01ACTION (.*?)\x01?\z/m, 1])
      @hub.broadcast(SYSTEM, "#{self.class.clean(from)} #{self.class.clean(action)}")
    elsif !text.start_with?("\x01")
      body = self.class.clean(text)
      @hub.broadcast(self.class.clean(from), body) unless body.empty?
    end
  end

  def lost
    was = @mu.synchronize do
      @members.clear
      @joined.tap { @joined = false }
    end
    @hub.broadcast(SYSTEM, 'The IRC connection dropped, reconnecting…') if was
  end

  def here?(target) = target.to_s.casecmp?(@channel)
  def me?(nick)     = nick.to_s.casecmp?(@current)

  def send_line(text)
    @sock&.write("#{text}\r\n")
  end

  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
