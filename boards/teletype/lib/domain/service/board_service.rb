# frozen_string_literal: true

class BoardService
  COOLDOWN = 30

  def initialize(repo)
    @repo = repo
    @last = {}
    @mu   = Mutex.new
  end

  def boards               = @repo.boards
  def board(id)            = @repo.boards.find { |b| b.id == id }
  def messages(id, n = 30) = @repo.last(id, n)
  def count(id)            = @repo.count(id)
  def total_count          = @repo.total_count

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
