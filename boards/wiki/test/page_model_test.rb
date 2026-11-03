# frozen_string_literal: true

require 'test_helper'

class PageModelTest < Minitest::Test
  def page(route) = PageModel.new(route: route, title: 'T', updated_at: '2026-11-03', tags: [], private: false)

  def test_public_url_is_the_page_on_the_web
    assert_equal 'https://wiki.teletypegames.org/engines/rubbs', page('/engines/rubbs').public_url
    assert_equal 'https://wiki.teletypegames.org/', page('/').public_url
  end
end
