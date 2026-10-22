# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# Posts board messages and sysop broadcasts to a Discord webhook, in the
# background so a slow webhook never stalls a telnet session. Without a
# webhook URL it does nothing. Mentions are disabled: a caller cannot ping
# @everyone from the BBS.
class DiscordNotifier
  LIMIT = 300

  def initialize(webhook)
    @uri = webhook.to_s.empty? ? nil : URI(webhook)
  end

  def enabled? = !@uri.nil?

  def board_post(board_title, username, text)
    notify("📟 **#{escape(username)}** on *#{escape(board_title)}*: #{clip(text)}")
  end

  def broadcast(username, text)
    notify("📢 Sysop broadcast from **#{escape(username)}**: #{clip(text)}")
  end

  def page(username)
    notify("🔔 **#{escape(username)}** is paging the sysop on the Teletype BBS (telnet teletypegames.org:2323)")
  end

  # Only that a letter came: what it says stays on the board.
  def feedback(username)
    notify("✉️ New feedback for the sysop from **#{escape(username)}**: read it in Messages > Mail")
  end

  private

  def clip(text)
    flat = text.to_s.gsub(/\s+/, ' ').strip
    escape(flat.length > LIMIT ? "#{flat[0, LIMIT]}…" : flat)
  end

  # Discord markdown off, links included: a caller's [text](url) stays text.
  def escape(text) = text.to_s.gsub(/([\\*_~`|>\[\]()<#:-])/) { "\\#{Regexp.last_match(1)}" }

  def notify(content)
    return unless enabled?

    Thread.new do
      body = JSON.generate(content: content, allowed_mentions: { parse: [] })
      Net::HTTP.post(@uri, body, 'Content-Type' => 'application/json')
    rescue StandardError => e
      warn "DiscordNotifier error: #{e}"
    end
  end
end
