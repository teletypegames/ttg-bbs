# frozen_string_literal: true

module TTG
  module Bulletin
    # The bulletin as a service of the Central, on <tt>/bulletin</tt>, for
    # accounts only. Op: +today+, the lines of the day (TTG::Bulletin.lines)
    # the first time an account asks on a day, no lines after that.
    class Service < Rubbs::Common::Central::Service
      path     '/bulletin'
      database :bulletin, MIGRATIONS

      op(:today) { |actor, **| actor.guest? ? :guest : today(actor) }

      # The lines of the day for +actor+ (an account) once a day: +{ lines: }+.
      def today(actor, at: Time.now)
        day  = at.strftime('%Y-%m-%d')
        seen = database[:bulletin_seen]
        return { lines: [] } if seen.where(account_id: actor.id).get(:day) == day

        lines = Bulletin.lines(at)
        seen.insert_conflict(:replace).insert(account_id: actor.id, day: day) unless lines.empty?
        { lines: lines }
      end
    end
  end
end
