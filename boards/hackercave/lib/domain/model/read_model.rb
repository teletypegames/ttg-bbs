# frozen_string_literal: true

require 'time'

# One time an RFC was opened on the board (a row of the reads table of
# data/hackercave.sqlite3); the class counts them.
class ReadModel < BBS::Model
  table :reads

  # Counts a read of RFC +number+ at +at+.
  def self.add(number, at: Time.now.utc) = insert(rfc: Integer(number), at: at.utc.iso8601)

  # How many times RFC +number+ was opened.
  def self.count_of(number) = where(rfc: Integer(number)).count

  # The +n+ most read RFCs as [number, reads], most read first.
  def self.top(n) = group_and_count(:rfc).order(Sequel.desc(:count), :rfc).limit(n).map { |r| [r[:rfc], r[:count]] }
end
