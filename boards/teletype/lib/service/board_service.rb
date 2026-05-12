# frozen_string_literal: true

class BoardService
  def initialize(repo) = @repo = repo

  def boards               = @repo.boards
  def board(id)            = @repo.boards.find { |b| b.id == id }
  def messages(id, n = 30) = @repo.last(id, n)
  def count(id)            = @repo.count(id)
  def total_count          = @repo.total_count

  def post(board_id, username, text)
    return :empty if text.to_s.strip.empty?
    @repo.append(board_id, username, text.strip[0...1000])
    :ok
  end
end
