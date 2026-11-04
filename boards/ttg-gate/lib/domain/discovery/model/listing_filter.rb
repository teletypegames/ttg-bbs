# frozen_string_literal: true

module Discovery
  # Which boards a list of the Gate shows (ListingModel.matching).
  #
  # [tags]     every one must be on the board
  # [match]    an FTS5 query the board must match, or nil
  # [dead]     whether dead boards are in it
  # [state]    only boards in this state (the F filter), or nil
  # [petscii]  only PETSCII boards (the C64 face)
  # [mailers]  whether FTN mailers (sw:ftn-mailer: mail programs answering a
  #            nodelist's telnet flag, not BBSes) are in it; by default only
  #            when the tag is asked for
  class ListingFilter < Data.define(:tags, :match, :dead, :state, :petscii, :mailers)
    MAILER = 'sw:ftn-mailer'

    def initialize(tags: [], match: nil, dead: false, state: nil, petscii: false, mailers: nil)
      mailers = tags.include?(MAILER) if mailers.nil?
      super(tags: tags.freeze, match: match, dead: dead || state == 'dead' || tags.include?('dead'),
            state: state, petscii: petscii, mailers: mailers)
    end

    # The filter of a SearchQuery.
    def self.search(query, petscii: false, state: nil)
      new(tags: query.tags, match: query.match, dead: query.all?, state: state, petscii: petscii)
    end
  end
end
