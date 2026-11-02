# frozen_string_literal: true

require 'test_helper'

class WikiRepositoryTest < Minitest::Test
  SITEMAP = { 'pages' => [{ 'route' => '/a', 'title' => "A\e]52;c;x\a page", 'updatedAt' => '2026-10-01T10:00',
                            'tags' => ["t\u202e"], 'private' => false }] }.freeze
  PAGE    = { 'title' => "Hi\e[2J", 'markdown' => "line\n\e[31mred" }.freeze

  def repository = @repository ||= WikiRepository.new('http://wiki-grav', user_agent: 'Test/1', token: 'secret')

  def test_the_sitemap_is_cleaned
    page = FakeWiki.new('/custom/sitemap.json' => [200, SITEMAP]).serve { repository.sitemap.first }
    assert_equal ['/a', 'A]52;c;x page', '2026-10-01', ['t']], [page.route, page.title, page.updated_at, page.tags]
  end

  def test_a_page_is_cleaned_and_cached
    wiki = FakeWiki.new('/custom/page.json' => [200, PAGE])
    2.times { assert_equal({ 'title' => 'Hi[2J', 'markdown' => "line\n[31mred" }, wiki.serve { repository.page('/a') }) }
    assert_equal 1, wiki.urls.size
  end

  def test_requests_go_to_the_docker_network_with_the_user_agent
    wiki = FakeWiki.new('/custom/page.json' => [200, PAGE])
    wiki.serve { repository.page('/a') }
    assert_equal({ user_agent: 'Test/1', public_only: false }, wiki.urls.first[1])
  end

  def test_the_token_goes_only_with_a_private_page
    wiki = FakeWiki.new('/custom/page.json' => [200, PAGE])
    wiki.serve do
      repository.page('/open')
      repository.page('/closed', private: true)
    end
    refute wiki.urls[0][1].key?(:headers)
    assert_equal({ 'X-Wiki-Token' => 'secret' }, wiki.urls[1][1][:headers])
    refute_includes wiki.urls[1][0], 'secret'
  end

  def test_an_error_never_names_the_token
    wiki = FakeWiki.new('/custom/page.json' => [502, 'Bad gateway'])
    error = assert_raises(WikiRepository::Error) { wiki.serve { repository.page('/closed', private: true) } }
    assert_equal 'HTTP 502 for /custom/page.json', error.message
  end

  def test_php_notices_before_the_json_are_skipped
    wiki = FakeWiki.new('/custom/page.json' => [200, "Deprecated: x\n#{JSON.generate(PAGE)}"])
    assert_equal 'Hi[2J', wiki.serve { repository.page('/a') }['title']
  end

  def test_an_answer_that_is_no_json_is_an_error
    wiki = FakeWiki.new('/custom/page.json' => [200, '<html>Bad gateway</html>'])
    error = assert_raises(WikiRepository::Error) { wiki.serve { repository.page('/a') } }
    assert_equal 'the answer is not JSON', error.message
  end
end
