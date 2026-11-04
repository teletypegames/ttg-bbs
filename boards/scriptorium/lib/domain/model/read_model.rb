# frozen_string_literal: true

require 'time'

# One time a book was opened on the board (a row of the reads table of
# data/scriptorium.sqlite3); the class counts them.
class ReadModel < BBS::Model
  table :reads

  # Counts a read of book +book_id+ at +at+.
  def self.add(book_id, at: Time.now.utc) = insert(book_id: Integer(book_id), at: at.utc.iso8601)

  # How many times book +book_id+ was opened.
  def self.count_of(book_id) = where(book_id: Integer(book_id)).count

  # Whether nothing was read yet.
  def self.none? = dataset.empty?

  # The +n+ most read books as [id, reads], most read first.
  def self.top(n) = group_and_count(:book_id).order(Sequel.desc(:count), :book_id).limit(n).map { |r| [r[:book_id], r[:count]] }
end
