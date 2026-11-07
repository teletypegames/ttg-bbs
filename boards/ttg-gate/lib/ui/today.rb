# frozen_string_literal: true

# The faces of TTG Gate BBS.
module UI
  # What answers the Today page (a Herald::Edition) of the caller on
  # +session+, on either face: TTGGateBBS#today with the caller's address;
  # nothing for a gate without one.
  def self.today(session, bbs)
    return -> {} unless bbs.respond_to?(:today)

    ip = session.respond_to?(:caller_ip) ? session.caller_ip : nil
    -> { bbs.today(ip: ip) }
  end
end
