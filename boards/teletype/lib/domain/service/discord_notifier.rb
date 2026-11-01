# frozen_string_literal: true

require 'bbs/discord_webhook'

# Posts board messages and sysop broadcasts to a Discord webhook through
# BBS::DiscordWebhook: in the background, so a slow webhook never stalls a
# telnet session; nothing without a webhook URL; mentions off, so a caller
# cannot ping @everyone from the BBS; and at most 20 posts in ten minutes,
# however many callers post: the rest stay on the board only, so a crowd
# (or one caller redialling past the post cooldown) cannot flood the channel.
class DiscordNotifier
  LIMIT = 300

  def initialize(webhook)
    @hook = BBS::DiscordWebhook.new(webhook, label: 'DiscordNotifier')
  end

  def enabled? = @hook.enabled?

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

  def clip(text) = escape(BBS::DiscordWebhook.clip(text, LIMIT))

  def escape(text) = BBS::DiscordWebhook.escape(text)

  def notify(content) = @hook.post(content)
end
