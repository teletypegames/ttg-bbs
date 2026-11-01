# frozen_string_literal: true

require_relative 'test_helper'
require 'socket'

module Discovery
  class TelnetTest < Minitest::Test
    N = TelnetNegotiator

    def bytes(*codes) = codes.flat_map { |c| c.is_a?(String) ? c.bytes : [c] }.pack('C*')

    def test_fixed_answers
      telnet = N.new
      data, reply = telnet.feed(bytes(N::IAC, N::DO, N::TTYPE, N::IAC, N::DO, N::NAWS, N::IAC, N::WILL, 1,
                                      N::IAC, N::DO, 0, N::IAC, N::WILL, 3, 'Hi', N::IAC, N::IAC))
      assert_equal bytes('Hi', 255), data
      assert_equal bytes(N::IAC, N::WILL, N::TTYPE,
                         N::IAC, N::WILL, N::NAWS, N::IAC, N::SB, N::NAWS, 0, 80, 0, 25, N::IAC, N::SE,
                         N::IAC, N::DONT, 1, N::IAC, N::WONT, 0, N::IAC, N::DONT, 3), reply
      assert_equal ['DO TTYPE', 'DO NAWS', 'WILL ECHO', 'DO BINARY', 'WILL SGA'], telnet.options
    end

    def test_terminal_type_is_ansi
      telnet = N.new
      telnet.feed(bytes(N::IAC, N::DO, N::TTYPE))
      _, reply = telnet.feed(bytes(N::IAC, N::SB, N::TTYPE, 1, N::IAC, N::SE))
      assert_equal bytes(N::IAC, N::SB, N::TTYPE, 0, 'ANSI', N::IAC, N::SE), reply
    end

    def test_commands_split_across_reads_and_no_second_answer
      telnet = N.new
      assert_equal ['', ''], telnet.feed(bytes(N::IAC)).map(&:b)
      _, reply = telnet.feed(bytes(N::WILL, 1))
      assert_equal bytes(N::IAC, N::DONT, 1), reply
      _, reply = telnet.feed(bytes(N::IAC, N::WILL, 1, N::IAC, N::WONT, 1, N::IAC, N::DONT, 24))
      assert_equal '', reply
      assert_equal ['WILL ECHO', 'WONT ECHO', 'DONT TTYPE'], telnet.options
    end

    # A board on a local port: +script+ gets the client socket.
    def board(&script)
      server = TCPServer.new('127.0.0.1', 0)
      @received = +''.b
      thread = Thread.new do
        client = server.accept
        script.call(client)
      rescue IOError, SystemCallError
        nil
      ensure
        client&.close
      end
      [server.addr[1], server, thread]
    end

    def call(port, **)
      TelnetProbe.new(connect_timeout: 2, read_timeout: 1.5, nudge_after: 0.5, **).call('127.0.0.1', port)
    end

    def test_a_banner
      port, server, thread = board do |c|
        c.write(bytes(N::IAC, N::DO, N::TTYPE, "\e[2JWelcome to Synchronet\r\n"))
        sleep 2
      end
      result = call(port)
      assert_equal 'ok', result.result
      assert_equal "\e[2JWelcome to Synchronet\r\n".b, result.banner
      assert_equal ['DO TTYPE'], result.options
      assert_equal '127.0.0.1', result.ip
      refute_nil result.latency_ms
    ensure
      server&.close
      thread&.kill
    end

    def test_a_silent_board_gets_one_cr
      got = Queue.new
      port, server, thread = board do |c|
        got << c.readpartial(10)
        sleep 2
      end
      result = call(port)
      assert_equal 'silent', result.result
      assert_equal "\r", got.pop
    ensure
      server&.close
      thread&.kill
    end

    def test_a_board_waiting_for_enter_answers_it
      port, server, thread = board do |c|
        c.readpartial(10)
        c.write('Login: ')
        sleep 2
      end
      assert_equal 'Login: ', call(port).banner
    ensure
      server&.close
      thread&.kill
    end

    def test_closed
      port, server, thread = board(&:close)
      assert_equal 'closed', call(port).result
    ensure
      server&.close
      thread&.kill
    end

    def test_at_most_4_kb
      port, server, thread = board do |c|
        c.write('x' * 10_000)
        sleep 2
      end
      assert_equal 4096, call(port).banner.bytesize
    ensure
      server&.close
      thread&.kill
    end

    def test_refused
      server = TCPServer.new('127.0.0.1', 0)
      port = server.addr[1]
      server.close
      result = call(port)
      assert_equal 'refused', result.result
      assert_nil result.latency_ms
    end

    def test_dns_fail
      result = TelnetProbe.new(resolver: ->(_) { [] }).call('gone.invalid', 23)
      assert_equal 'dns_fail', result.result
      assert_nil result.ip
    end
  end
end
