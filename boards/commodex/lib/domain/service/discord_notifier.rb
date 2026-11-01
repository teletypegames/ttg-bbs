# frozen_string_literal: true

require 'bbs/discord_webhook'

# A new pending tip on the admins' Discord channel, with the command that
# approves it: a BBS::DiscordWebhook of rubbs, so it posts in the
# background, mentions off, links without embeds, at most 20 tips in ten
# minutes.
class DiscordNotifier
  def initialize(webhook:)
    @hook = BBS::DiscordWebhook.new(webhook, embeds: false, label: 'commodex: Discord')
  end

  def call(tip, game)
    @hook.post("🕹️ Commodex: a tip for **#{escape(game.title)}** from #{escape(tip.author)} (##{tip.id}, pending)\n" \
               ">>> #{escape(tip.text)}\n\n`docker exec commodex bin/tips approve #{tip.id}`")
  end

  private

  def escape(text) = BBS::DiscordWebhook.escape(text)
end
