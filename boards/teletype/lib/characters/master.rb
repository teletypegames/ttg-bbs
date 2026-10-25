# frozen_string_literal: true

require 'yaml'
require_relative 'llm'

# The TTG Master, the sysop who answers callers: the code looks up the facts
# for the question (the board's knowledge, the latest releases, the coming
# events, the games), and the model only words them. A question with no
# facts is not sent to the model at all, so it cannot make up a menu.
class TtgMaster
  def self.stem(word) = word.to_s.downcase.sub(/(?<=...)s\z/, '')

  def self.knowledge(file)
    YAML.safe_load_file(File.join(__dir__, file)).map do |entry|
      [entry.fetch('keys').map { |k| k.split.map { |w| stem(w) }.join(' ') }.uniq, entry.fetch('fact')]
    end.freeze
  end

  PERSONA   = BBS::AI::Persona.load(File.join(__dir__, 'master.yml'))
  KNOWLEDGE = knowledge('master_knowledge.yml')
  # The same sysop on the C64 board, where the way around is single keys.
  C64 = { persona:   BBS::AI::Persona.load(File.join(__dir__, 'master_c64.yml')),
          knowledge: knowledge('master_knowledge_c64.yml'),
          catalog:   'G on the main menu' }.freeze
  MAX_FACTS = 2

  # Words that sit in many questions weigh half: "board" in "who made this
  # board" must not win over "made".
  GENERIC_WORDS = %w[board door game file program system menu line play].freeze

  NEWS_WORDS   = %w[new latest release recent update news].freeze
  EVENT_WORDS  = %w[event party jam meeting deadline upcoming next when coming].freeze
  LIST_WORDS   = %w[which list all what].freeze

  # +catalog+ is where the board keeps the game catalog, for the catalog fact.
  def initialize(games:, site:, persona: PERSONA, knowledge: KNOWLEDGE, catalog: 'Content > Game Catalog')
    @games     = games
    @site      = site
    @persona   = persona
    @knowledge = knowledge
    @catalog   = catalog
    @chat      = BBS::AI::Chat.new(persona: persona, client: Characters.client, key: :master_history, history: 0)
  end

  MENU_PATH = %r{\b[A-Z][\w/-]*(?: [A-Z][\w/-]*)* > [A-Z0-9][\w/…-]*(?: [A-Z0-9][\w/…-]*)*}

  Fact = Struct.new(:text, :anchors)

  # The reply, whole: the model words the facts, and the code checks the
  # wording before it is shown. Without facts, without the model, or when
  # the wording lost the facts' anchors or names a menu that is not in
  # them, the caller gets the fact itself.
  def answer(question, ctx = {})
    if (canned = @persona.deflect(question))
      return canned
    end

    facts = facts_for(question)
    return @persona.fallback(question) if facts.empty?

    reply = @chat.reply("Facts:\n#{facts.map { |f| "- #{f.text}" }.join("\n")}\nQuestion: #{question}", ctx,
                        fallback: facts.first.text)
    faithful?(reply, facts) ? reply : facts.first.text
  end

  def facts_for(question)
    words = question.downcase.scan(/[[:alnum:]]+/).map { |w| self.class.stem(w) }
    phrase = " #{words.join(' ')} "
    found = @knowledge.map { |keys, text| [score(keys, words, phrase), text] }
                      .select { |score, _| score.positive? }
                      .sort_by { |score, _| -score }.first(MAX_FACTS)
                      .map { |_, text| Fact.new(text, text.scan(MENU_PATH)) }
    live = []
    live << releases if words.intersect?(NEWS_WORDS)
    live << events if words.intersect?(EVENT_WORDS)
    live << catalog if words.intersect?(platforms) || (words.include?('game') && words.intersect?(LIST_WORDS))
    (live.compact + found).uniq(&:text).first(MAX_FACTS + 1)
  end

  private

  # A phrase key ("who made") counts double, a generic word half.
  def score(keys, words, phrase)
    keys.sum do |key|
      if key.include?(' ') then phrase.include?(" #{key} ") ? 2 : 0
      elsif words.include?(key) then GENERIC_WORDS.include?(key) ? 0.5 : 1
      else 0
      end
    end
  end

  def faithful?(reply, facts)
    anchors = facts.flat_map(&:anchors)
    paths   = facts.flat_map { |f| f.text.scan(MENU_PATH) }
    text    = reply.downcase
    return false unless anchors.empty? || anchors.any? { |a| text.include?(a.downcase) }

    reply.scan(MENU_PATH).all? { |path| paths.any? { |known| known.start_with?(path) || path.start_with?(known) } }
  end

  def platforms = @games.platforms.map { |p| self.class.stem(p) }

  def releases
    latest = @games.latest_releases(3)
    return nil if latest.empty?

    list = latest.map { |g| "#{g.title} #{g.version} (#{g.platform}, #{g.released_at.strftime('%Y-%m-%d')})" }
    Fact.new("The latest releases: #{list.join('; ')}.", latest.map(&:title))
  end

  def events
    coming = @site.upcoming_events(3)
    return Fact.new('No events are scheduled right now.', []) if coming.empty?

    Fact.new("Coming up: #{coming.map { |e| "#{e.name} on #{e.date.strftime('%Y-%m-%d')}" }.join('; ')}.",
             coming.map(&:name) + coming.map { |e| e.date.strftime('%Y-%m-%d') })
  end

  def catalog
    by_platform = @games.all.select(&:released?).group_by(&:platform)
    return nil if by_platform.empty?

    list = by_platform.sort.map { |p, gs| "#{p}: #{gs.map(&:title).uniq.join(', ')}" }
    Fact.new("The games by platform: #{list.join('; ')}. #{@catalog} has them all.",
             by_platform.values.flatten.map(&:title) + [@catalog])
  end
end
