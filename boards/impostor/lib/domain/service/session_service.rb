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
  # kept, and nothing is when the player name is no name (a scanner's line).
  # Returns +self+, as a store does.
  def upsert(session_id:, **fields)
    return self unless SessionModel.player?(**fields)

    kept = SessionModel.fields(**fields)
    @repository.save(session_id, kept) unless kept.empty?
    self
  end

  # The SessionModel of the call +session_id+, or +nil+.
  def find(session_id) = @repository.find(session_id)

  # The feedback the board kept before the network's, as rows of
  # TTG::Feedback's import: the +debrief+ kind, the player's name, read
  # already.
  def feedback_rows
    @repository.all.reject { |row| row['feedback'].to_s.strip.empty? }.map do |row|
      {
        kind:       'debrief',
        name:       row['player_name'],
        subject:    '',
        body:       row['feedback'],
        context:    "Player #{row['player_name']}",
        created_at: row['timestamp'],
        state:      'read'
      }
    end
  end
end
