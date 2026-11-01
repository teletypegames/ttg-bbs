# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

# A new pending tip on the admins' Discord channel, with the command that
# approves it. In the background, so a slow webhook never stalls a call;
# mentions are off and the caller's text goes in as plain text. At most
# RELAY_MAX tips ring Discord in RELAY_WINDOW seconds.
class DiscordNotifier
  MAX          = 1500
  RELAY_MAX    = 20
  RELAY_WINDOW = 600

  def initialize(webhook:)
    @webhook = URI(webhook)
    @lock    = Mutex.new
    @sent    = []
  end

  def call(tip, game)
    return warn('commodex: Discord relay limit reached, not sent') unless slot?

    content = "🕹️ Commodex: a tip for **#{escape(game.title)}** from #{escape(tip.author)} (##{tip.id}, pending)\n" \
              ">>> #{escape(tip.text)}\n\n`docker exec commodex bin/tips approve #{tip.id}`"
    body = JSON.generate(content: content[0, MAX], allowed_mentions: { parse: [] }, flags: 4)
    Thread.new do
      Net::HTTP.post(@webhook, body, 'Content-Type' => 'application/json')
    rescue StandardError => e
      warn "commodex: Discord error: #{e}"
    end
  end

  private

  def slot?
    @lock.synchronize do
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @sent.shift while @sent.any? && now - @sent.first > RELAY_WINDOW
      next false if @sent.size >= RELAY_MAX

      @sent << now
      true
    end
  end

  def escape(text) = text.to_s.gsub(/([\\*_~`|>\[\]()<#:@-])/) { "\\#{Regexp.last_match(1)}" }
end
