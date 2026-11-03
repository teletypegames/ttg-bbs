# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'bbs'
require_relative '../lib/domain'

# A catalog snapshot of a few records, without a file.
module Fixtures
  module_function

  def records
    { 'series' => [{ 'id' => 'Q16290', 't' => 'Star Trek: The Next Generation', 's' => 1987, 'e' => 1994,
                     'ma' => 'Star Trek: The Next Generation' },
                   { 'id' => 'films', 't' => 'The films', 's' => 1979, 'e' => 2016 }],
      'episodes' => [
        { 'id' => 'Q2', 't' => 'The Naked Now', 'se' => 'Q16290', 'sn' => 1, 'n' => 3, 'd' => '1987-10-05' },
        { 'id' => 'Q1', 't' => 'Encounter at Farpoint', 'se' => 'Q16290', 'sn' => 1, 'n' => 1, 'd' => '1987-09-28',
          'dir' => ['Corey Allen'], 'ma' => 'Encounter at Farpoint (episode)' },
        { 'id' => 'Q3', 't' => "Yesterday's Enterprise", 'se' => 'Q16290', 'sn' => 3, 'n' => 15, 'd' => '1990-02-19' },
        { 'id' => 'Q9', 't' => 'Star Trek II: The Wrath of Khan', 'se' => 'films', 'd' => '1982-06-04',
          'ma' => 'Star Trek II: The Wrath of Khan' }
      ] }
  end

  # A BBS::Snapshot stand-in holding the records.
  Snapshot = Struct.new(:value, :generated_at)

  def catalog = CatalogService.new(Snapshot.new(CatalogModel.from_records(records), Time.now))
end
