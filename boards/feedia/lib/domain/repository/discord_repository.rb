# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# The admins' Discord channel, through its webhook. A post goes out in the
# background, so a slow webhook never stalls a call, with mentions off (a
# caller cannot ping @everyone) and no link embeds. At most RELAY_MAX posts
# go out in RELAY_WINDOW seconds, so a crowd cannot flood the channel.
# Without a webhook it does nothing.
class DiscordRepository
  MAX_CONTENT  = 1500
  RELAY_MAX    = 20
  RELAY_WINDOW = 600

  def initialize(webhook)
    @webhook = webhook.to_s.empty? ? nil : URI(webhook)
    @mu      = Mutex.new
    @sent    = []
  end

  # Posts +content+ (cut at MAX_CONTENT).
  def post(content)
    return unless @webhook
    return warn('Inbox: Discord relay limit reached, not sent') unless relay_slot?

    Thread.new do
      body = JSON.generate(content: content[0, MAX_CONTENT], allowed_mentions: { parse: [] }, flags: 4)
      Net::HTTP.post(@webhook, body, 'Content-Type' => 'application/json')
    rescue StandardError => e
      warn "Discord error: #{e}"
    end
  end

  private

  # True when one more post fits in the window, and counts it.
  def relay_slot?
    @mu.synchronize do
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @sent.shift while @sent.any? && now - @sent.first > RELAY_WINDOW
      next false if @sent.size >= RELAY_MAX

      @sent << now
      true
    end
  end
end
