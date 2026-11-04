# frozen_string_literal: true

require_relative 'test_helper'
require 'bbs/test'
require_relative '../../lib/domain/service/accounts_metrics'

# The accounts in numbers, as the textfile collector reads them.
class AccountsMetricsTest < Minitest::Test
  def test_the_gauges
    stats = { accounts: 3, roles: { 'member' => 3, 'sysop' => 1 }, new_day: 1, new_week: 2, seen_day: 2, seen_week: 3 }
    text  = AccountsMetrics.new(nil, nil).text(stats)
    assert_includes text, "ttg_bbs_accounts 3\n"
    assert_includes text, %(ttg_bbs_accounts_by_role{role="sysop"} 1\n)
    assert_includes text, %(ttg_bbs_accounts_new{window="7d"} 2\n)
    assert_includes text, %(ttg_bbs_accounts_seen{window="1d"} 2\n)
    assert_equal 4, text.scan('# TYPE').size
  end

  def test_the_file_is_written_whole
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'accounts.prom')
      capture_io { BBS::Test.accounts.tap { |a| a.register('Ada', 'secret1') }.then { |a| AccountsMetrics.new(a, path).write } }
      assert_includes File.read(path), "ttg_bbs_accounts 1\n"
      refute File.exist?("#{path}.tmp")
    end
  end
end
