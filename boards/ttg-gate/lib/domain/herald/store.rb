# frozen_string_literal: true

require 'json'

module Herald
  # What the sources fetched last, one row a source (data/herald.sqlite3,
  # HeraldModel): the Today tab reads only this, so a caller never waits for
  # the web.
  class Store
    # A source's last fetch: its +payload+ (parsed JSON) and when
    # (+fetched_at+, epoch seconds).
    Entry = Data.define(:payload, :fetched_at)

    # Keeps +payload+ (anything JSON carries) as +source+'s, fetched +at+.
    def put(source, payload, at: Time.now.to_i)
      HeraldModel.put(source.to_s, JSON.generate(payload), at)
    end

    # The Entry of +source+, or +nil+.
    def get(source)
      row = HeraldModel.row(source.to_s)
      row && Entry.new(payload: JSON.parse(row[:payload]), fetched_at: row[:fetched_at])
    rescue JSON::ParserError
      nil
    end
  end
end
