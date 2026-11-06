# frozen_string_literal: true

# The board's view of the network's letters and of its wall (ttg-common TTG::PrivateMessage and
# TTG::Wall on the Central): a caller's mailbox at a glance and the post office's desk. +letters+
# and +walls+ give the services' proxies when asked (the Central is tied to the board after the
# domain starts). A desk is kept CACHE seconds a caller, so a desktop that repaints every second
# asks the Central only now and then.
class MailService
  # Seconds a desk is kept.
  CACHE = 20
  # Letters and notes on the desk.
  DESK = 3

  def initialize(letters, walls = -> {}, clock: -> { Time.now })
    @letters = letters
    @walls   = walls
    @clock   = clock
    @desks   = {}
    @mutex   = Mutex.new
  end

  # The MailboxSummaryModel of +actor+ (a Rubbs::Common::Central::Actor): no letters for a guest.
  def summary(actor)
    return MailboxSummaryModel.new(unread: 0, reachable: true) if actor.guest?

    answer = @letters.call.call(:unread, actor)
    return MailboxSummaryModel.away unless answer['result'] == 'ok'

    MailboxSummaryModel.new(unread: answer['count'].to_i, reachable: true)
  end

  # The DeskModel of +actor+, at most CACHE seconds old.
  def desk(actor)
    key = actor.id || "guest:#{actor.caller_key}"
    @mutex.synchronize do
      kept = @desks[key]
      return kept[1] if kept && @clock.call - kept[0] < CACHE
    end
    fresh = build(actor)
    @mutex.synchronize { @desks[key] = [@clock.call, fresh] }
    fresh
  end

  private

  def build(actor)
    summary = summary(actor)
    return DeskModel.away unless summary.reachable

    DeskModel.new(summary: summary, letters: letters_of(actor), notes: notes)
  end

  def letters_of(actor)
    return [] if actor.guest?

    (@letters.call.call(:inbox, actor, limit: DESK)['letters'] || []).map do |letter|
      { from: letter['from_name'], subject: letter['subject'].to_s, new: letter['read_at'].nil? }
    end
  end

  def notes
    walls = @walls.call or return []

    (walls.call(:recent, nil, limit: DESK)['notes'] || []).map { |note| { name: note['name'], text: note['text'] } }
  end
end
