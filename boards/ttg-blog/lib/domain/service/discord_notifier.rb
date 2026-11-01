# frozen_string_literal: true

# A new post on the Discord channel of a webhook, with its link on the web,
# through BBS::DiscordWebhook: in the background, so a slow webhook never
# stalls the editor's call; mentions are off, and the text goes in as plain
# text.
class DiscordNotifier
  def initialize(webhook:, site:)
    @hook = BBS::DiscordWebhook.new(webhook, relay_max: nil, label: 'ttg-blog-bbs: Discord')
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

  def escape(text) = BBS::DiscordWebhook.escape(text)
end
