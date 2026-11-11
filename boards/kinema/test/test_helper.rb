# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'json'
require 'rubbs'
require 'rubbs/test'
require_relative '../lib/domain'
require_relative '../lib/ui/wording'
require_relative '../lib/ui/rows'

# A catalog snapshot of a few records, without a file.
module Fixtures
  module_function

  def records
    { 'films' => [
      {
        'id'  => 'Q1',
        't'   => 'Casablanca',
        'y'   => 1942,
        'd'   => '1942-11-26',
        'l'   => 90,
        'dir' => ['Michael Curtiz'],
        'g'   => ['drama film', 'romance film']
      },
      {
        'id'  => 'Q2',
        't'   => 'Stalker',
        'hu'  => 'Sztalker',
        'y'   => 1979,
        'd'   => '1979-05-25',
        'l'   => 80,
        'dir' => ['Andrei Tarkovsky'],
        'g'   => ['science fiction film', 'drama film']
      },
      { 'id' => 'Q3', 't' => 'Solaris', 'y' => 1972, 'l' => 70, 'g' => ['science fiction film'] },
      { 'id' => 'Q4', 't' => 'Mirror', 'hu' => 'Tükör', 'y' => 1975, 'd' => '1975-03-07', 'l' => 60, 'g' => ['drama film'] }
    ] }
  end

  # A Rubbs::Common::Storage::Snapshot stand-in holding the records.
  Snapshot = Struct.new(:value, :generated_at)

  def catalog(genres: 2)
    CatalogService.new(Snapshot.new(CatalogModel.from_records(records), Time.now), min_genre: genres)
  end

  def entity(name) = JSON.parse(File.read(File.join(__dir__, 'fixtures', "#{name}.json")))['entities'].values.first
end

# A signed-in account, or a guest.
def account(id = 7, name = 'Ada') = Rubbs::Common::Auth::Identity.new(id: id, name: name, source: :login)

def guest = Rubbs::Common::Auth::Identity.guest
