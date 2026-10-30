# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

# A new post on the Discord channel of a webhook, with its link on the web.
# In the background, so a slow webhook never stalls the editor's call;
# mentions are off, and the text goes in as plain text.
class DiscordNotifier
  MAX = 1500

  def initialize(webhook:, site:)
    @webhook = URI(webhook)
    @site    = site.chomp('/')
  end

  def call(post)
    head  = ["📝 **#{escape(post.title)}**", post.author && escape(post.author)].compact.join(' · ')
    lines = [head]
    lines << escape(post.summary) unless post.summary.empty?
    lines << "#{@site}/blog/#{post.slug}"
    body = JSON.generate(content: lines.join("\n")[0, MAX], allowed_mentions: { parse: [] })
    Thread.new do
      Net::HTTP.post(@webhook, body, 'Content-Type' => 'application/json')
    rescue StandardError => e
      warn "ttgblog: Discord error: #{e}"
    end
  end

  private

  def escape(text) = text.to_s.gsub(/([\\*_~`|>\[\]()<#:@-])/) { "\\#{Regexp.last_match(1)}" }
end
