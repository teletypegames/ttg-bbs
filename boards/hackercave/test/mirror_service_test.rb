# frozen_string_literal: true

require 'test_helper'

class MirrorServiceTest < Minitest::Test
  include TempDir

  # An rsync that writes two RFCs into the folder it is given; the second
  # run changes one.
  class FakeRsync
    attr_reader :runs

    def initialize = @runs = 0

    def call(args)
      dir = args.last
      FileUtils.mkdir_p(dir)
      @runs += 1
      File.write(File.join(dir, 'rfc1149.txt'), "IP datagrams on Avian Carriers\nthe pigeon\n")
      File.write(File.join(dir, 'rfc854.txt'), @runs == 1 ? "TELNET PROTOCOL\n" : "TELNET PROTOCOL SPECIFICATION\nwindow\n")
      File.write(File.join(dir, 'notes.txt'), 'not an RFC')
      true
    end
  end

  # An RFC Editor with the text of IEN 137.
  class FakeEditor
    def text(number) = number == -137 ? "ON HOLY WARS AND A PLEA FOR PEACE\nlittle-endians\n" : raise(BBS::HTTP::Error, '404')
  end

  def setup
    super
    @rsync = FakeRsync.new
    @mirror = MirrorService.new(texts: TextRepository.new(path('rfc')), fulltext: FulltextRepository.new(path('ft.sqlite3')),
                                index: index, editor: FakeEditor.new, ttl: 86_400, rsync: @rsync)
  end

  def test_a_sync_indexes_the_texts_and_the_iens
    refute @mirror.ready?
    assert_equal 3, @mirror.refresh
    assert @mirror.ready?
    assert_equal [[1149, 'IP datagrams on Avian Carriers']], @mirror.search(%w[avian], limit: 10)
    assert_equal [[-137, 'little-endians']], @mirror.search(%w[endians], limit: 10)
    assert_equal :fresh, @mirror.refresh
  end

  def test_only_what_changed_is_indexed_again
    @mirror.refresh
    assert_equal 1, @mirror.refresh(force: true)
    assert_equal [854], @mirror.search(%w[window], limit: 10).map(&:first)
    assert_empty @mirror.search(%w[pigeons], limit: 10)
    assert_equal [1149], @mirror.search(%w[pige], limit: 10).map(&:first)
  end
end
