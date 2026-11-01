# frozen_string_literal: true

# The cheats and tips of the games. A caller's tip waits as pending until an
# admin approves it (bin/tips); only approved tips are shown. A caller (by
# address: BBS::RateLimit.caller_key, so hanging up and calling again does
# not help) may send PER_CALLER tips an hour, one every GAP seconds, and the
# whole board at most BOARD_MAX an hour, so a crowd cannot flood the queue.
class TipService
  MAX_TEXT   = 500
  MAX_HANDLE = 20
  PER_CALLER = 3
  GAP        = 30
  BOARD_MAX  = 30
  WINDOW     = 3600

  def initialize(repository, catalog:, notifier: nil, seeds: [])
    @repository = repository
    @catalog    = catalog
    @notifier   = notifier
    @limits     = [BBS::RateLimit.new(limit: 1, per: GAP), BBS::RateLimit.new(limit: PER_CALLER, per: WINDOW)]
    @board      = BBS::RateLimit.new(limit: BOARD_MAX, per: WINDOW)
    seeds.each { |s| @repository.insert(**s, status: 'approved') }
  end

  def tips(game) = @repository.approved(game.id)

  def count(game) = @repository.count_approved(game.id)

  # The games that have an approved tip, by title.
  def games_with_tips = @repository.approved_counts.keys.filter_map { |id| @catalog.find(id) }.sort_by { |g| g.title.downcase }

  # Sends a tip for +game+ from +caller+ (BBS::RateLimit.caller_key): :ok,
  # or why not: :empty, :too_long, :rate_limited, :failed.
  def submit(game, text:, caller:, handle: '')
    text = clean(text)
    return :empty if text.empty?
    return :too_long if text.size > MAX_TEXT
    return :rate_limited unless allowed?(caller)

    save(game, text, clean(handle)[0, MAX_HANDLE])
  end

  def pending(limit = 100) = @repository.with_status('pending', limit: limit)

  def approved_list(limit = 100) = @repository.with_status('approved', limit: limit)

  def find(id) = @repository.find(id)

  def game_of(tip) = @catalog.find(tip.game_id)

  # :ok or :no_tip.
  def approve(id) = status(id, 'approved')

  def reject(id) = status(id, 'rejected')

  private

  def status(id, value) = @repository.change_status(id.to_i, value).positive? ? :ok : :no_tip

  # One line of text: no control or bidirectional character, one space
  # between words.
  def clean(text) = BBS::Text.clean(text.to_s).gsub(/[[:space:]]+/, ' ').strip

  # Whether +caller+ and the board may send one more; counts it when they may.
  def allowed?(caller) = @limits.all? { |limit| limit.allow?(caller) } && @board.allow?(:board)

  def save(game, text, handle)
    id = @repository.insert(game_id: game.id, handle: handle, text: text)
    @notifier&.call(@repository.find(id), game)
    :ok
  rescue StandardError => e
    warn "commodex-bbs: saving a tip: #{e.class}: #{e.message}"
    :failed
  end
end
