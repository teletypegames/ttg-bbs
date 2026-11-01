# frozen_string_literal: true

require 'time'

# What callers send the admins: a feed to add, or feedback. Every message
# is kept in the inbox and rings the admins' Discord channel. The board
# never fetches a suggested address: that is the admins' call, from their
# own machine. Results are symbols for the faces to word.
class InboxService
  MAX_TEXT  = 1000
  MAX_FIELD = 200
  # The messages one call may send: enough for anyone, too few for a flood.
  PER_CALL  = 5

  def self.url?(url) = url.to_s.strip.match?(%r{\Ahttps?://[^\s/]+\.[^\s]+\z}i)

  def initialize(inbox, discord:)
    @inbox   = inbox
    @discord = discord
  end

  # :ok, or why not: :no_url, :bad_url, :failed.
  def suggest(url:, name: '', note: '', from: '')
    url = field(url)
    return :no_url if url.empty?
    return :bad_url unless InboxService.url?(url)

    deliver(MessageModel.from_h(kind: 'suggestion', at: Time.now.iso8601, from: field(from), name: field(name), url: url,
                                text: text(note)))
  end

  # :ok, or why not: :empty, :failed.
  def feedback(text:, from: '')
    body = text(text)
    return :empty if body.empty?

    deliver(MessageModel.from_h(kind: 'feedback', at: Time.now.iso8601, from: field(from), text: body))
  end

  # The newest messages first, for the admins' look at the inbox.
  def messages(limit = 50) = @inbox.last(limit)

  private

  def deliver(message)
    return :failed unless @inbox.append(message)

    @discord.post(discord_text(message))
    :ok
  end

  def field(value) = HtmlText.clean(value).gsub(/\s+/, ' ').strip[0, MAX_FIELD]

  def text(value) = HtmlText.clean(value).gsub(/[ \t]+/, ' ').gsub(/\n{3,}/, "\n\n").strip[0, MAX_TEXT]

  def discord_text(message)
    who  = message.from.to_s.empty? ? 'a caller' : "**#{escape(message.from)}**"
    head = if message.kind == 'suggestion'
             "📰 Feedia: #{who} suggests a feed: #{escape(message.name.to_s)} <#{message.url}>"
           else
             "💬 Feedia: feedback from #{who}"
           end
    message.text.to_s.empty? ? head : "#{head}\n>>> #{escape(message.text)}"
  end

  # Discord markdown off, links included: a caller's [text](url) stays text.
  def escape(text) = text.to_s.gsub(/([\\*_~`|>\[\]()<#:@-])/) { "\\#{Regexp.last_match(1)}" }
end
