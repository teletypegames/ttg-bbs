# frozen_string_literal: true

require 'yaml'

module Discovery
  # The code-level config of Global Discovery, read once: the sources and
  # their priority (config/discovery/sources.yml), the software signatures
  # (software.yml) and the source-to-tag rules (source-map.yml). A file that
  # cannot be read raises: a broken config must stop the importer, not empty
  # the catalog.
  class ConfigRepository
    Signature = Data.define(:id, :name, :pattern)
    Rule      = Data.define(:source, :field, :pattern, :tag)

    def initialize(dir)
      @dir = dir
    end

    def sources
      @sources ||= load('sources.yml').fetch('sources').map { |r| SourceModel.from(r) }.freeze
    end

    def source(id) = sources.find { |s| s.id == id }

    # The source ids, most trusted first; sources missing from the list come
    # after, in the order of the file.
    def priority
      @priority ||= (Array(load('sources.yml')['priority']).map(&:to_s) | sources.map(&:id)).freeze
    end

    def signatures
      @signatures ||= load('software.yml').fetch('signatures').map do |r|
        Signature.new(id: r.fetch('id').to_s, name: r.fetch('name').to_s,
                      pattern: Regexp.new(r.fetch('pattern'), Regexp::IGNORECASE))
      end.freeze
    end

    # The rules of an axis of source-map.yml (:encoding or :network).
    def rules(axis)
      @rules ||= {}
      @rules[axis] ||= Array(load('source-map.yml')[axis.to_s]).map do |r|
        Rule.new(source: r.fetch('source').to_s, field: r.fetch('field').to_s,
                 pattern: Regexp.new(r.fetch('pattern'), Regexp::IGNORECASE), tag: r.fetch('tag').to_s)
      end.freeze
    end

    private

    def load(name) = YAML.safe_load_file(File.join(@dir, name))
  end
end
