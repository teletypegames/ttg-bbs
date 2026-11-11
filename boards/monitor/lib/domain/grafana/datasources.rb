# frozen_string_literal: true

module Grafana
  # A data source: its +uid+, +type+ (+prometheus+, +loki+, +mysql+ …) and
  # +name+.
  Source = Data.define(:uid, :type, :name)

  # The data sources a token sees (<tt>/api/frontend/settings</tt>): found
  # by a panel's reference (<tt>{ uid:, type: }</tt>, a name, a variable
  # like <tt>${ds}</tt>, or none: the default).
  class Datasources
    # The uid of the built-in "-- Grafana --" source (test data, files).
    GRAFANA = 'grafana'
    # The names of the sources that are not one: a panel's queries each
    # with their own (Mixed), another panel's results (Dashboard).
    MIXED = ['-- Mixed --', '-- Dashboard --'].freeze

    # The sources of a frontend settings +answer+.
    def initialize(answer)
      list = (answer['datasources'] || {}).map do |name, ds|
        Source.new(uid: (ds['uid'] || name).to_s, type: ds['type'].to_s, name: name.to_s)
      end
      @by_uid  = list.to_h { |s| [s.uid, s] }
      @by_name = list.to_h { |s| [s.name, s] }
      @default = @by_name[answer['defaultDatasource'].to_s] || list.find { |s| s.type != 'datasource' }
    end

    # The Source of +ref+ (put through +interpolator+ when it names a
    # variable), the default when there is none; +nil+ for one that is not
    # a single source (Mixed, Dashboard) or cannot be found.
    def find(ref, interpolator = nil)
      return @default if ref.nil? || ref == ''

      if ref.is_a?(Hash)
        uid = expand(ref['uid'], interpolator)
        return @default if uid.empty? && ref['type'].to_s.empty?

        @by_uid[uid] || @by_name[uid] || (uid.empty? ? nil : Source.new(uid: uid, type: ref['type'].to_s, name: uid))
      else
        name = expand(ref, interpolator)
        MIXED.include?(name) ? nil : @by_name[name] || @by_uid[name]
      end
    end

    # The default source.
    attr_reader :default

    # Whether +ref+ is the Mixed source (each query names its own) or none.
    def self.mixed?(ref)
      uid = ref.is_a?(Hash) ? ref['uid'].to_s : ref.to_s
      ['-- Mixed --', 'mixed'].include?(uid)
    end

    # Whether +ref+ takes another panel's results.
    def self.dashboard?(ref)
      uid = ref.is_a?(Hash) ? ref['uid'].to_s : ref.to_s
      ['-- Dashboard --', 'dashboard'].include?(uid)
    end

    private

    def expand(value, interpolator) = interpolator ? interpolator.apply(value.to_s) : value.to_s
  end
end
