# frozen_string_literal: true

require 'test_helper'
require 'ttg/check'
require 'fileutils'
require 'tmpdir'

class TTGCheckTest < Minitest::Test
  RUBOCOP  = "inherit_gem:\n  ttg-common: lib/ttg/board/rubocop.yml\n"
  SETTINGS = "shop: { port: 2390, max_sessions: 50, memory: 160m }\n"

  def files
    {
      'bbs.rb'       => "require 'ttg/common'\nboard = Rubbs.board 'Shop BBS' do\n  preset TTG::PRESET\nend\n\n" \
                        "board.run! if Rubbs.main?(__FILE__)\n",
      '.rubocop.yml' => RUBOCOP,
      'env-example'  => ''
    }
  end

  def with_board(changes = {}, settings: SETTINGS, folder: 'shop')
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'boards.yml'), settings) if settings
      dir = File.join(tmp, 'boards', folder)
      files.merge(changes).compact.each do |path, text|
        FileUtils.mkdir_p(File.join(dir, File.dirname(path)))
        File.write(File.join(dir, path), text)
      end
      yield dir
    end
  end

  def ttg_findings(dir) = Rubbs::Common::Board::Check.run(dir).select { |f| f.rule.to_s.start_with?('ttg_') }

  def test_a_board_by_the_house_rules
    with_board { |dir| assert_empty ttg_findings(dir) }
  end

  def test_what_breaks_the_house_rules
    changes = {
      '.rubocop.yml' => "AllCops:\n  NewCops: enable\n",
      'bbs.rb'       => "board = Rubbs.board 'Shop BBS' do\nend\n",
      'env-example'  => nil
    }
    with_board(changes) do |dir|
      assert_equal %i[ttg_files ttg_preset ttg_rubocop], ttg_findings(dir).map(&:rule).uniq.sort
    end
  end

  def test_the_folder_is_the_name_without_bbs
    with_board(folder: 'shop-bbs', settings: SETTINGS.sub('shop:', 'shop-bbs:')) do |dir|
      assert_equal [:ttg_name], ttg_findings(dir).map(&:rule)
    end
  end

  def test_the_board_is_in_boards_yml
    with_board(settings: nil) { |dir| assert_equal [:ttg_settings], ttg_findings(dir).map(&:rule) }
    with_board(settings: "other: {}\n") { |dir| assert_equal ['no shop'], ttg_findings(dir).map(&:message) }
    with_board(settings: "shop: { port: 80, max_sessions: 5 }\n") do |dir|
      assert_equal ['shop: no memory', 'shop: port not in 2300..2399'], ttg_findings(dir).map(&:message)
    end
  end

  def test_a_board_with_accounts_lists_the_secret
    bbs = "require 'ttg/common'\nboard = Rubbs.board 'Shop BBS' do\n  preset TTG::PRESET\n  auth TTG::AUTH, login: :menu\n" \
          "end\n\nboard.run! if Rubbs.main?(__FILE__)\n"
    with_board({ 'bbs.rb' => bbs }) { |dir| assert_equal [:ttg_auth], ttg_findings(dir).map(&:rule) }
    with_board({ 'bbs.rb' => bbs, 'env-example' => "RUBBS_AUTH_SECRET=\n" }) { |dir| assert_empty ttg_findings(dir) }
  end
end
