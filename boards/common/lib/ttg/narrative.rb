# frozen_string_literal: true

require 'yaml'

module TTG
  # What a screen of TTG::Feedback or TTG::Wall says, which a board may say
  # its own way: the module gives every text (its defaults), the board
  # overrides only what it wants, in Ruby or in a YAML file of its own
  # (<tt>lib/content/feedback.yml</tt>, <tt>lib/content/wall.yml</tt>).
  #
  #   narrative = TTG::Narrative.new(TTG::Feedback::DEFAULTS, 'lib/content/feedback.yml')
  #   narrative.text(:title)                    # the board's, else the default
  #   narrative.text(:intro, petscii: true)     # the C64's shorter one, if given
  #   narrative.kinds.keys                      # => [:feed, :feedback]
  #   narrative.kind(:feed).text(:intro)        # the kind's own, else the screen's
  #
  # A key the defaults do not have is an error when the board starts, not a
  # text quietly never shown. A field (+subject+, +body+, +link+, +name+) is a
  # Hash: +label+, +hint+, +required+, +max+, and +off+ to leave it out.
  class Narrative
    # The keys a kind may have: its +label+ in the list of kinds, and the
    # screen's keys it says its own way.
    KIND_KEYS = %i[label intro subject body link thanks].freeze
    # The keys of a field.
    FIELD_KEYS = %i[label hint required max off].freeze

    # Raised when an override has a key the defaults do not know.
    class UnknownKey < ArgumentError; end

    # The texts: +defaults+ (a Hash) with +override+ over them (a Hash, the
    # path of a YAML file, or +nil+; a path that does not exist is no
    # override). +petscii+ texts sit under the key +:petscii+.
    def initialize(defaults, override = nil, kinds: nil)
      @defaults = symbolize(defaults)
      own = symbolize(read(override))
      check(own, @defaults.keys + %i[petscii kinds], 'narrative')
      check(own[:petscii] || {}, @defaults.keys, 'petscii')
      @data  = merge(@defaults, own)
      @kinds = (kinds || own[:kinds] || @defaults[:kinds] || {}).to_h { |key, value| [key.to_sym, symbolize(value || {})] }
      @kinds.each { |key, value| check(value, KIND_KEYS + [:petscii], "kind #{key}") }
    end

    # The text +key+: the C64's when +petscii+ and one is given, else the
    # modern one; +nil+ when there is none.
    def text(key, petscii: false)
      return @data.dig(:petscii, key) if petscii && @data.dig(:petscii, key)

      @data[key]
    end

    # The field +key+ (a Hash of FIELD_KEYS), +nil+ when it is off.
    def field(key)
      value = @data[key]
      value.is_a?(Hash) && !value[:off] ? value : nil
    end

    # The kinds, in order: a Hash of Symbol => Hash.
    attr_reader :kinds

    # The narrative of kind +key+: the screen's, with what the kind says its
    # own way over it.
    # A field the kind gives is on, even when the screen's is off.
    def kind(key)
      own = @kinds.fetch(key.to_sym, {}).except(:label).to_h do |name, value|
        field = value.is_a?(Hash) && name != :petscii && @data[name].is_a?(Hash)
        [name, field ? { off: false }.merge(value) : value]
      end
      Narrative.new(@data.except(:kinds), own, kinds: {})
    end

    # The label of kind +key+.
    def kind_label(key) = @kinds.dig(key.to_sym, :label) || key.to_s.tr('_', ' ').capitalize

    private

    def read(override)
      return override if override.is_a?(Hash)
      return {} if override.nil? || !File.exist?(override.to_s)

      YAML.safe_load_file(override.to_s) || {}
    end

    def check(hash, allowed, where)
      unknown = hash.keys - allowed
      raise UnknownKey, "#{where}: unknown #{unknown.join(', ')}" unless unknown.empty?

      hash.each do |key, value|
        next unless !%i[petscii kinds].include?(key) && value.is_a?(Hash) && @defaults[key].is_a?(Hash)

        extra = value.keys - FIELD_KEYS
        raise UnknownKey, "#{where} #{key}: unknown #{extra.join(', ')}" unless extra.empty?
      end
    end

    def merge(base, over)
      base.merge(over) { |_, old, new| old.is_a?(Hash) && new.is_a?(Hash) ? merge(old, new) : new }
    end

    def symbolize(value)
      case value
      when Hash then value.to_h { |key, inner| [key.to_sym, symbolize(inner)] }
      else value
      end
    end
  end
end
