# frozen_string_literal: true

module Discovery
  # One telnet endpoint as a source list gives it, before it meets the catalog:
  # the normalized +host+ and +port+, the fields the list has (nil when it has
  # none), and +hints+, the list's own fields that only a rule of
  # config/discovery/source-map.yml may turn into a tag (a SyncTERM ScreenMode,
  # an SBL service comment, the SBL networks, the platform of the CBBS
  # list).
  class RecordModel < Data.define(:source_id, :host, :port, :name, :sysop, :location, :software, :since, :ftn_address,
                                  :hardware, :website, :hints)
    # The fields a board takes from its sources, in the order of the board's page.
    FIELDS = %i[name sysop location software since ftn_address hardware website].freeze

    def initialize(source_id:, host:, port:, name: nil, sysop: nil, location: nil, software: nil, since: nil,
                   ftn_address: nil, hardware: nil, website: nil, hints: {})
      super
    end

    def key = "#{host}:#{port}"

    # The fields and the hints as one Hash with String keys, nils left out: what
    # board_sources.fields keeps.
    def stored_fields
      FIELDS.to_h { |f| [f.to_s, public_send(f)] }.compact.merge(hints.transform_keys(&:to_s))
    end
  end
end
