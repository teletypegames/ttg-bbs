# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class NoticeServiceTest < Minitest::Test
  def test_a_notice_by_its_id
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'notices.yml')
      File.write(path, "- id: hello\n  title: Hello\n  body: First notice.\n")
      notices = NoticeService.new(NoticeRepository.new(path))
      assert_equal 'Hello', notices.find('hello').title
      assert_equal :unknown, notices.find('nope')
    end
  end
end
