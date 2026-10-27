# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'time'
require 'fileutils'
require_relative 'html_text'

# What callers send the admins: a feed to add, or feedback. Every message is
# a JSON line in the inbox file, and rings the admins' Discord webhook when
# there is one, in the background so a slow webhook never stalls a call.
# Mentions are off: a caller cannot ping @everyone. The reader never fetches
# a suggested address: that is the admins' call, from their own machine.
class Inbox
  MAX_TEXT    = 1000
  MAX_FIELD   = 200
  PER_CALL    = 5
  DISCORD_MAX = 1500

  Message = Struct.new(:kind, :at, :from, :name, :url, :text, keyword_init: true)

  def self.url?(url) = url.to_s.strip.match?(%r{\Ahttps?://[^\s/]+\.[^\s]+\z}i)

  def initialize(path:, webhook: nil)
    @path    = path
    @webhook = webhook.to_s.empty? ? nil : URI(webhook)
    @mu      = Mutex.new
  end

  # :ok, or why not: :no_url, :bad_url, :empty.
  def suggest(url:, name: '', note: '', from: '')
    url = field(url)
    return :no_url if url.empty?
    return :bad_url unless Inbox.url?(url)

    deliver(Message.new(kind: 'suggestion', at: Time.now.iso8601, from: field(from), name: field(name), url: url,
                        text: text(note)))
  end

  def feedback(text:, from: '')
    body = text(text)
    return :empty if body.empty?

    deliver(Message.new(kind: 'feedback', at: Time.now.iso8601, from: field(from), text: body))
  end

  # The newest messages first, for the admins' look at the inbox.
  def messages(limit = 50)
    return [] unless File.exist?(@path)

    File.readlines(@path, chomp: true).last(limit).reverse.filter_map do |line|
      Message.new(**JSON.parse(line).transform_keys(&:to_sym).slice(*Message.members))
    rescue JSON::ParserError
      nil
    end
  end

  private

  def deliver(message)
    @mu.synchronize do
      FileUtils.mkdir_p(File.dirname(@path))
      File.open(@path, 'a') { |f| f.puts(JSON.generate(message.to_h.compact)) }
    end
    notify(message)
    :ok
  rescue SystemCallError => e
    warn "Inbox error: #{e.class}: #{e.message}"
    :failed
  end

  def field(value) = HtmlText.clean(value).gsub(/\s+/, ' ').strip[0, MAX_FIELD]

  def text(value) = HtmlText.clean(value).gsub(/[ \t]+/, ' ').gsub(/\n{3,}/, "\n\n").strip[0, MAX_TEXT]

  def notify(message)
    return unless @webhook

    who  = message.from.to_s.empty? ? 'a caller' : "**#{escape(message.from)}**"
    head = if message.kind == 'suggestion'
             "📰 Feedia: #{who} suggests a feed: #{escape(message.name.to_s)} <#{message.url}>"
           else
             "💬 Feedia: feedback from #{who}"
           end
    content = message.text.to_s.empty? ? head : "#{head}\n>>> #{escape(message.text)}"
    Thread.new do
      body = JSON.generate(content: content[0, DISCORD_MAX], allowed_mentions: { parse: [] }, flags: 4)
      Net::HTTP.post(@webhook, body, 'Content-Type' => 'application/json')
    rescue StandardError => e
      warn "Discord error: #{e}"
    end
  end

  # Discord markdown off, links included: a caller's [text](url) stays text.
  def escape(text) = text.to_s.gsub(/([\\*_~`|>\[\]()<#:@-])/) { "\\#{Regexp.last_match(1)}" }
end
