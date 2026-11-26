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

  # What answers the Trophy Room (a Trophies::Room) on either face:
  # TTGGateBBS#trophies; nothing for a gate without one.
  def self.trophies(bbs)
    return -> {} unless bbs.respond_to?(:trophies)

    -> { bbs.trophies }
  end
end
