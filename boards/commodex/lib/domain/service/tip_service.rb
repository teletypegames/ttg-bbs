# frozen_string_literal: true

# The cheats and tips of the games. A caller's tip waits as pending until an
# admin approves it (bin/tips); only approved tips are shown. A call may
# send PER_SESSION tips, one every GAP seconds, and the whole board at most
# GLOBAL_MAX in GLOBAL_WINDOW seconds, so a crowd cannot flood the queue.
class TipService
  MAX_TEXT      = 500
  MAX_HANDLE    = 20
  PER_SESSION   = 3
  GAP           = 30
  GLOBAL_MAX    = 30
  GLOBAL_WINDOW = 3600

  def initialize(repository, catalog:, notifier: nil, seeds: [])
    @repository = repository
    @catalog    = catalog
    @notifier   = notifier
    @lock       = Mutex.new
    @sessions   = {}
    @recent     = []
    seeds.each { |s| @repository.insert(**s, status: 'approved') }
  end

  def tips(game) = @repository.approved(game.id)

  def count(game) = @repository.count_approved(game.id)

  # The games that have an approved tip, by title.
  def games_with_tips = @repository.approved_counts.keys.filter_map { |id| @catalog.find(id) }.sort_by { |g| g.title.downcase }

  # Sends a tip for +game+ from the call +session+: :ok, or why not:
  # :empty, :too_long, :rate_limited, :failed.
  def submit(game, text:, session:, handle: '')
    text = clean(text)
    return :empty if text.empty?
    return :too_long if text.size > MAX_TEXT
    return :rate_limited unless slot?(session)

    handle = clean(handle)[0, MAX_HANDLE]
    id = @repository.insert(game_id: game.id, handle: handle, text: text)
    @notifier&.call(@repository.find(id), game)
    :ok
  rescue StandardError => e
    warn "commodex: saving a tip: #{e.class}: #{e.message}"
    :failed
  end

  # How many more tips the call +session+ may send.
  def left(session) = PER_SESSION - @lock.synchronize { @sessions.fetch(session, []).size }

  def pending(limit = 100) = @repository.with_status('pending', limit: limit)

  def approved_list(limit = 100) = @repository.with_status('approved', limit: limit)

  def find(id) = @repository.find(id)

  def game_of(tip) = @catalog.find(tip.game_id)

  # :ok or :no_tip.
  def approve(id) = status(id, 'approved')

  def reject(id) = status(id, 'rejected')

  private

  def status(id, value) = @repository.set_status(id.to_i, value).positive? ? :ok : :no_tip

  def clean(text) = text.to_s.gsub(/[[:cntrl:]]/, ' ').gsub(/\s+/, ' ').strip

  # True when the call and the board may send one more, and counts it.
  def slot?(session)
    @lock.synchronize do
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @recent.shift while @recent.any? && now - @recent.first > GLOBAL_WINDOW
      @sessions.delete_if { |_, times| now - times.last > GLOBAL_WINDOW }
      mine = @sessions.fetch(session, [])
      next false if mine.size >= PER_SESSION || (mine.any? && now - mine.last < GAP) || @recent.size >= GLOBAL_MAX

      @sessions[session] = [*mine, now]
      @recent << now
      true
    end
  end
end
