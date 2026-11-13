# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'time'
require 'json'

# What the board gives the network's Daily Herald (the Today tab of TTG Gate BBS): the machine of
# the week, written to +path+ as JSON (board, heading, title, text, until) for the gate to read.
# The file is written again only when the week turns.
class HeraldService
  BOARD   = 'siliconia-bbs'
  HEADING = 'Machine of the week'

  def initialize(catalog:, path:)
    @catalog = catalog
    @path    = path
  end

  # The note of +at+'s week, a Hash; nil when the catalog has no machine for it.
  def note(at = Time.now)
    machine = @catalog.machine_of_the_week(at)
    return nil unless machine

    {
      'board'   => BOARD,
      'heading' => HEADING,
      'week'    => @catalog.week(at),
      'id'      => machine.id,
      'title'   => machine.label,
      'text'    => [machine.kind_name, *machine.makers.first(1), *machine.cpus.first(1)].join(' · '),
      'until'   => week_end(at).utc.iso8601
    }
  end

  # Writes the note of +at+'s week unless the file has it already: :written, :same or :none.
  def publish(at = Time.now)
    note = note(at)
    return :none unless note
    return :same if current == note

    FileUtils.mkdir_p(File.dirname(@path))
    File.write("#{@path}.tmp", JSON.generate(note))
    File.rename("#{@path}.tmp", @path)
    :written
  end

  private

  def current
    File.exist?(@path) ? JSON.parse(File.read(@path)) : nil
  rescue JSON::ParserError
    nil
  end

  # The Monday after +at+, midnight local time.
  def week_end(at)
    day = at.to_date
    monday = day + (8 - day.cwday)
    Time.local(monday.year, monday.month, monday.day)
  end
end
