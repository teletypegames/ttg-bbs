# frozen_string_literal: true

require 'io/wait'
require 'resolv'
require 'socket'

module Discovery
  # One call to a board (TTG_DISCOVERY.md §5.1): DNS (A, then AAAA), a TCP
  # connection in at most 10 s, the telnet answers of TelnetNegotiator, then
  # reading for at most 8 s or 4 KB. When 4 s pass without a byte of banner,
  # one CR goes out (many boards wait for ENTER); nothing else is ever sent,
  # and it never logs in. Returns a ProbeResultModel; a name that resolves to
  # no public address (Address.callable?) is a dns_fail, and is not called.
  #
  # With +c64+ the call is a Commodore 64's (TTG_DISCOVERY.md §5.1): the same
  # connection and one CR (0x0D), but no telnet option is accepted, so a board
  # that adapts to its caller shows what a C64 would get; and a longer
  # window, for a real C64 behind tcpser that answers late: up to C64_FIRST
  # seconds for the first byte, reading until C64_TOTAL seconds (or 4 KB).
  class TelnetProbe
    CONNECT_TIMEOUT = 10
    READ_TIMEOUT    = 8
    NUDGE_AFTER     = 4
    MAX_BANNER      = 4096
    DNS_TIMEOUT     = 5
    C64_FIRST       = 20
    C64_TOTAL       = 25

    def initialize(connect_timeout: CONNECT_TIMEOUT, read_timeout: READ_TIMEOUT, nudge_after: NUDGE_AFTER,
                   c64_first: C64_FIRST, c64_total: C64_TOTAL,
                   resolver: method(:resolve), callable: Address.method(:callable?),
                   clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @callable        = callable
      @connect_timeout = connect_timeout
      @read_timeout    = read_timeout
      @c64_first       = c64_first
      @c64_total       = c64_total
      @nudge_after     = nudge_after
      @resolver        = resolver
      @clock           = clock
    end

    def call(host, port, c64: false)
      at = Time.now.to_i
      begun = @clock.call
      ips = @resolver.call(host)
      return ProbeResultModel.new(result: 'dns_fail', at: at, duration_ms: since(begun)) unless @callable.call(ips, port)

      ip = ips.first

      started = @clock.call
      socket = connect(ip, port)
      return ProbeResultModel.new(result: socket, at: at, ip: ip, duration_ms: since(begun)) if socket.is_a?(String)

      latency = since(started)
      window = c64 ? [@c64_first, @c64_total] : [@read_timeout, @read_timeout]
      result, banner, options = converse(socket, TelnetNegotiator.new(c64: c64), *window)
      ProbeResultModel.new(result: result, at: at, latency_ms: latency, ip: ip, banner: banner, options: options,
                           duration_ms: since(begun))
    ensure
      socket.close if socket.is_a?(Socket) && !socket.closed?
    end

    # The addresses of +host+, IPv4 first; an IP address is its own.
    def resolve(host)
      return [host] if Address.ip?(host)

      Resolv::DNS.open do |dns|
        dns.timeouts = DNS_TIMEOUT
        v4 = dns.getresources(host, Resolv::DNS::Resource::IN::A).map { |r| r.address.to_s }
        v4.empty? ? dns.getresources(host, Resolv::DNS::Resource::IN::AAAA).map { |r| r.address.to_s } : v4
      end
    rescue Resolv::ResolvError, SystemCallError
      []
    end

    private

    def since(start) = ((@clock.call - start) * 1000).round

    # A connected Socket, or the result: refused or timeout.
    def connect(ip, port)
      Socket.tcp(ip, port, connect_timeout: @connect_timeout)
    rescue Errno::ECONNREFUSED
      'refused'
    rescue SystemCallError, SocketError, IO::TimeoutError
      'timeout'
    end

    # [result, banner, options] of the conversation on +socket+: reading
    # until +total+ seconds, or +first+ seconds when no byte came.
    def converse(socket, telnet, first, total)
      banner  = +''.b
      start   = @clock.call
      nudged  = false
      eof     = false
      loop do
        elapsed = @clock.call - start
        limit = banner.empty? ? first : total
        break if elapsed >= limit || banner.bytesize >= MAX_BANNER

        if banner.empty? && !nudged && elapsed >= @nudge_after
          socket.write("\r")
          nudged = true
        end
        wait = [limit - elapsed, nudged || !banner.empty? ? limit : @nudge_after - elapsed].min
        next unless socket.wait_readable([wait, 0.05].max)

        data, reply = telnet.feed(socket.read_nonblock(4096))
        socket.write(reply) unless reply.empty?
        banner << data
      rescue IO::WaitReadable
        next
      rescue EOFError, Errno::ECONNRESET, Errno::EPIPE
        eof = true
        break
      end
      banner = banner.byteslice(0, MAX_BANNER)
      result = if banner.empty? then eof ? 'closed' : 'silent'
               else 'ok'
               end
      [result, banner, telnet.options]
    end
  end
end
