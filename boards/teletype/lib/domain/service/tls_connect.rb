# frozen_string_literal: true

require 'openssl'
require 'socket'

# A verified TLS connection with a deadline on the whole of it: TCP, then
# the handshake. A server that stops halfway raises IOError instead of
# holding the caller's thread forever.
module TlsConnect
  module_function

  def open(host, port, timeout:)
    tcp  = Socket.tcp(host, port, connect_timeout: timeout)
    sock = OpenSSL::SSL::SSLSocket.new(tcp, context)
    sock.hostname   = host
    sock.sync_close = true
    handshake(sock, monotonic + timeout)
    sock.post_connection_check(host)
    sock
  rescue StandardError
    sock ? sock.close : tcp&.close
    raise
  end

  def context = OpenSSL::SSL::SSLContext.new.tap { |ctx| ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER) }

  def handshake(sock, deadline)
    loop do
      return sock.connect_nonblock
    rescue IO::WaitReadable, IO::WaitWritable => e
      left  = deadline - monotonic
      ready = e.is_a?(IO::WaitReadable) ? sock.to_io.wait_readable(left) : sock.to_io.wait_writable(left)
      raise IOError, 'the TLS handshake timed out' unless left.positive? && ready
    end
  end

  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
