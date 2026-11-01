# frozen_string_literal: true

require 'bbs/discord_webhook'

# The admins' Discord channel, through its webhook (BBS::DiscordWebhook): a
# post goes out in the background with mentions off and no link embeds, at
# most 20 in ten minutes. Without a webhook it does nothing.
class DiscordRepository
  def initialize(webhook)
    @hook = BBS::DiscordWebhook.new(webhook, embeds: false, label: 'Inbox: Discord')
  end

  # Posts +content+ (cut at 1500 characters).
  def post(content) = @hook.post(content)
end
