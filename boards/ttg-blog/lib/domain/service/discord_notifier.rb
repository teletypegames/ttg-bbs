# frozen_string_literal: true

# A new post on the Discord channel of a webhook, with its link on the web,
# through Rubbs::Common::Web::DiscordWebhook: in the background, so a slow webhook never
# stalls the editor's call; mentions are off, and the text goes in as plain
# text.
class DiscordNotifier
  def initialize(webhook:, site:)
    @hook = Rubbs::Common::Web::DiscordWebhook.new(webhook, relay_max: nil, label: 'Discord')
    @site = site.chomp('/')
  end

  def call(post)
    head  = ["📝 **#{escape(post.title)}**", post.author && escape(post.author)].compact.join(' · ')
    lines = [head]
    lines << escape(post.summary) unless post.summary.empty?
    lines << "#{@site}/blog/#{post.slug}"
    @hook.post(lines.join("\n"))
  end

  private

  def escape(text) = Rubbs::Common::Web::DiscordWebhook.escape(text)
end
