# frozen_string_literal: true

# The board's members. The accounts are the network's (Rubbs::Common::Auth, kept on
# TTG Gate BBS; the splash logs the caller in): +directory+ answers the
# Rubbs::Common::Auth::Directory (or Remote) of the board, nil when it has none. The
# callers who came in signed in are the board's members (MemberModel); a
# blank or malformed name is ANONYMOUS.
class MemberService
  ANONYMOUS = 'Anonymous'

  def initialize(directory:)
    @directory = directory
  end

  # +raw+ as a caller's name: trimmed, inner spaces single; ANONYMOUS when
  # it is not one an account may have (Rubbs::Common::Auth::Names.clean).
  def self.normalize_name(raw) = Rubbs::Common::Auth::Names.clean(raw) || ANONYMOUS

  def names            = MemberModel.names
  def created_at(name) = MemberModel.named(name)&.created_at

  # Remembers a signed-in +identity+ (a Rubbs::Common::Auth::Identity) as a member.
  def remember(identity)
    MemberModel.remember(identity) if identity.signed_in?
  end

  # The spelling of a member's name typed in any case, the name as typed
  # when it has an account that never called here, nil when nobody has it.
  def canonical(name)
    return nil if name.to_s.strip.empty?

    MemberModel.named(name)&.name || (name.to_s.strip if directory&.known?(name))
  end

  # A new account of +name+ with +password+ (said twice): its
  # Rubbs::Common::Auth::Identity, remembered as a member, or why not (:anonymous and
  # the answers of Rubbs::Common::Auth::Directory#register, or :unavailable).
  def register(name, password, confirm)
    return :anonymous if name.to_s.casecmp?(ANONYMOUS)

    result = directory&.register(name, password, confirm) || :unavailable
    remember(result) if result.is_a?(Rubbs::Common::Auth::Identity)
    result
  end

  private

  def directory = @directory.call
end
