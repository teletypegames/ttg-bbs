# frozen_string_literal: true

# How much new feedback waits for the sysops on the network's Central
# (ttg-common TTG::Feedback): the flag and the count on the clubhouse's
# mailbox, for a sysop only. Asked at most every TTL seconds; 0 when the
# Central does not answer, or answers that the asker is no sysop.
class FeedbackCounter
  TTL = 30

  # +source+ answers the counts for a Rubbs::Common::Central::Actor (the
  # Central's by default); +ttl+ the seconds a count is kept.
  def initialize(source: ->(actor) { TTG::Feedback.box.call(:counts, actor) }, ttl: TTL)
    @source = source
    @cache  = Rubbs::Common::Storage::Cache.new(ttl: ttl, max_entries: 1)
  end

  # The new feedback, as the sysop +actor+ is told.
  def new_count(actor)
    @cache.fetch(:new) do
      counts = @source.call(actor)['counts']
      counts.is_a?(Hash) ? counts['new'].to_i : 0
    end
  end
end
