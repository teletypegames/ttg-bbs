# frozen_string_literal: true

class BoardService
  COOLDOWN = 30

  def initialize(repo, last_read: nil)
    @repo      = repo
    @last_read = last_read
    @last = {}
    @mu   = Mutex.new
  end

  def boards               = @repo.boards
  def board(id)            = @repo.boards.find { |b| b.id == id }
  def messages(id, n = 30) = @repo.last(id, n)
  def count(id)            = @repo.count(id)
  def total_count          = @repo.total_count

  # Unread messages of a registered name on a board. A name that never
  # opened the board has read nothing of it.
  def unread(username, board_id)
    return 0 unless @last_read && username

    [count(board_id) - (@last_read.get(username, board_id) || 0), 0].max
  end

  # {board => unread} for the boards with something new.
  def new_scan(username)
    boards.to_h { |b| [b, unread(username, b.id)] }.select { |_, n| n.positive? }
  end

  def mark_read(username, board_id)
    @last_read&.set(username, board_id, count(board_id)) if username
  end

  # [[name, posts], ...] most posts first.
  def top_posters(n = 10)
    @repo.posters.values.reject { |name, _| name.casecmp?(AccountService::ANONYMOUS) }
         .sort_by { |name, posts| [-posts, name.downcase] }.first(n)
  end

  # :too_fast when the same session posted less than COOLDOWN seconds ago.
  def post(board_id, username, text, session_id: nil)
    return :empty if text.to_s.strip.empty?
    return :too_fast unless may_post?(session_id)

    @repo.append(board_id, username, text.strip[0...1000])
    :ok
  end

  private

  def may_post?(session_id)
    return true if session_id.nil?

    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @mu.synchronize do
      @last.delete_if { |_, at| now - at > COOLDOWN }
      return false if @last.key?(session_id)

      @last[session_id] = now
      true
    end
  end
end
