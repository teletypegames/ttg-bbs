# frozen_string_literal: true

require 'yaml'

# The boards of a YAML file (config/boards.yml), read once. A file that cannot
# be read or parsed gives no boards, and a record without an id, a name or a
# port is left out, each with a warning.
class BoardRepository
  # [path]        the YAML file
  # [host]        where the gate dials the boards
  # [public_host] the address shown to the caller
  # [local_host]  where the gate dials the boards that are not published
  def initialize(path, host:, public_host:, local_host: '127.0.0.1')
    @path        = path
    @host        = host
    @public_host = public_host
    @local_host  = local_host
  end

  def all
    @all ||= load
  end

  private

  def load
    records = YAML.safe_load_file(@path).fetch('boards', [])
    records.filter_map do |record|
      BoardModel.new(record, host: @host, public_host: @public_host, local_host: @local_host)
    rescue KeyError, ArgumentError, TypeError => e
      Rubbs.log('boards', "skipping a board in #{@path}: #{e.message}")
      nil
    end.freeze
  rescue SystemCallError, Psych::Exception, KeyError, NoMethodError => e
    Rubbs.log('boards', "cannot read #{@path}: #{e.class}: #{e.message}")
    [].freeze
  end
end
