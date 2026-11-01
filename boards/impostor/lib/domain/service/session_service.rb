# frozen_string_literal: true

# What the debrief terminal records of a call. The impostor gem's flow takes
# it as its sessions store: its persist steps call #upsert, and every field
# passes the rules of SessionModel before it is kept.
class SessionService
  def initialize(repository)
    @repository = repository
  end

  # Records +fields+ (name => what the caller typed) for the call
  # +session_id+; a field that does not pass SessionModel's rules is not
  # kept. Returns +self+, as a store does.
  def upsert(session_id:, **fields)
    kept = SessionModel.fields(**fields)
    @repository.save(session_id, kept) unless kept.empty?
    self
  end

  # The SessionModel of the call +session_id+, or +nil+.
  def find(session_id) = @repository.find(session_id)
end
