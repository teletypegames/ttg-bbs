# frozen_string_literal: true

require 'time'
require 'rubbs/common/line/rate_limit'
require 'rubbs/common/text'

# What callers send the admins: a feed to add, or feedback. Every message
# is kept in the inbox and rings the admins' Discord channel. The board
# never fetches a suggested address: that is the admins' call, from their
# own machine. A caller (Rubbs::Common::Line::RateLimit.caller_key) may send PER_CALLER
# messages an hour, all callers together GLOBAL; a message counts in both
# or, when one says no, in neither. Results are symbols for the faces to
# word.
class InboxService
  MAX_TEXT   = 1000
  MAX_FIELD  = 200
  # Messages an hour: enough for anyone, too few for a flood.
  PER_CALLER = 5
  GLOBAL     = 30
  HOUR       = 3600

  def self.url?(url) = url.to_s.strip.match?(%r{\Ahttps?://[^\s/]+\.[^\s]+\z}i)

  def initialize(
    discord:,
    per_caller: Rubbs::Common::Line::RateLimit.new(limit: PER_CALLER, per: HOUR),
    global: Rubbs::Common::Line::RateLimit.new(limit: GLOBAL, per: HOUR)
  )
    @discord    = discord
    @per_caller = per_caller
    @global     = global
  end

  # Whether +caller+ may send a message now, for a face to ask before it
  # opens a form.
  def open?(caller) = @per_caller.room?(caller) && @global.room?(:all)

  # :ok, or why not: :no_url, :bad_url, :limited, :failed.
  def suggest(caller:, url:, name: '', note: '', from: '')
    url = field(url)
    return :no_url if url.empty?
    return :bad_url unless InboxService.url?(url)

    deliver(caller, MessageModel.from_h(
                      kind: 'suggestion',
                      at:   Time.now.iso8601,
                      from: field(from),
                      name: field(name),
                      url:  url,
                      text: text(note)
                    ))
  end

  # :ok, or why not: :empty, :limited, :failed.
  def feedback(caller:, text:, from: '')
    body = text(text)
    return :empty if body.empty?

    deliver(caller, MessageModel.from_h(kind: 'feedback', at: Time.now.iso8601, from: field(from), text: body))
  end

  # The newest messages first, for the admins' look at the inbox.
  def messages(limit = 50) = MessageModel.last(limit)

  private

  def deliver(caller, message)
    return :limited unless Rubbs::Common::Line::RateLimit.allow_all?([[@per_caller, caller], [@global, :all]])

    MessageModel.append(message)
    @discord.post(discord_text(message))
    :ok
  rescue Sequel::DatabaseError => e
    Rubbs.log('inbox', "#{e.class}: #{e.message}")
    :failed
  end

  def field(value) = Rubbs::Common::Text.line(value)[0, MAX_FIELD]

  def text(value) = Rubbs::Common::Text.clean(value).gsub(/[ \t]+/, ' ').gsub(/\n{3,}/, "\n\n").strip[0, MAX_TEXT]

  def discord_text(message)
    head = message.kind == 'suggestion' ? suggestion_head(message) : "💬 Feedia BBS: feedback from #{who(message)}"
    message.text.to_s.empty? ? head : "#{head}\n>>> #{escape(message.text)}"
  end

  def suggestion_head(message)
    "📰 Feedia BBS: #{who(message)} suggests a feed: #{escape(message.name.to_s)} <#{message.url}>"
  end

  def who(message) = message.from.to_s.empty? ? 'a caller' : "**#{escape(message.from)}**"

  # Discord markdown off, links included: a caller's [text](url) stays text.
  def escape(text) = Rubbs::Common::Web::DiscordWebhook.escape(text)
end
