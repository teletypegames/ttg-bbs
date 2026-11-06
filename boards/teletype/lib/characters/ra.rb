# frozen_string_literal: true

require 'yaml'
require_relative 'llm'

# Ra, the sun god of Blessing of Ra: a persona the model plays, and the
# riddles of the pyramid, which the code asks and checks, so a right answer
# is always right.
module Ra
  PERSONA = Rubbs::Common::AI::Persona.load(File.join(__dir__, 'ra.yml'))
  RIDDLES = YAML.safe_load_file(File.join(__dir__, 'ra_riddles.yml')).freeze
  BLESSINGS = 3

  # Ra's voice: the model of +client+ (Characters.client) in Ra's persona.
  def self.chat(client) = Rubbs::Common::AI::Chat.new(persona: PERSONA, client: client, key: :ra_history, history: 2)

  GAME_WORDS = /\b(game|play|download|commodore|c64|plus.?4|version|catalog)\b/i

  PLATFORMS = { 'c64' => 'Commodore 64', 'plus4' => 'Plus/4' }.freeze

  # Where the tale is: the game behind the story, from the catalog. Ra says
  # it in the code's words, since a model this small mislays the address.
  def self.game_line(games)
    tales = games.all.select { |g| g.name.start_with?('blessingofra') && g.released? }
    return 'The scribes have not finished carving my tale yet.' if tales.empty?

    versions = tales.map { |g| "#{PLATFORMS.fetch(g.platform, g.platform)} #{g.version}" }.join(' and ')
    "The scribes of Teletype Games carved my tale for the Commodore machines (#{versions}). " \
      "Seek it at #{games.catalog_url(tales.first).sub(%r{\Ahttps?://}, '')}, and play the worker yourself."
  end

  # Ra's answer to free words in +chat+ (Ra.chat), typed out by +on_text+
  # as it streams.
  def self.reply(input, ctx, games, chat, &on_text)
    return game_line(games).tap { |line| on_text&.call(line) } if input.match?(GAME_WORDS)

    chat.reply(input, ctx, &on_text)
  end

  # One short answer: a line naming every answer at once is no answer.
  def self.answer?(riddle, text)
    words = text.downcase.scan(/[a-z]+/)
    words.size <= 4 && riddle['answers'].any? { |a| words.include?(a) }
  end
end
