# frozen_string_literal: true

require 'test_helper'

class WikiServiceTest < Minitest::Test
  # A repository with a fixed index that counts its reads.
  class Repository
    attr_reader :sitemaps, :clears

    def initialize(pages, page: {}, fail: false)
      @pages    = pages
      @page     = page
      @fail     = fail
      @sitemaps = 0
      @clears   = 0
    end

    def sitemap
      raise WikiRepository::Error, 'HTTP 502 for /custom/sitemap.json' if @fail
      @sitemaps += 1
      @pages
    end

    def page(_route, private: false) = @fail ? raise(WikiRepository::Error, 'HTTP 502') : @page.merge('private' => private)

    def clear_cache = @clears += 1
  end

  def page(route, private: false) = PageModel.new(route: route, title: route, updated_at: '', tags: [], private: private)

  def test_a_page_under_a_private_one_is_private_and_the_index_is_sorted
    service = WikiService.new(Repository.new([page('/z'), page('/p', private: true), page('/p/child')]))
    service.refresh_index!
    assert_equal([['/p', true], ['/p/child', true], ['/z', false]], service.pages.map { |p| [p.route, p.private?] })
  end

  def test_a_caller_refreshes_twice_a_minute_at_most
    repository = Repository.new([page('/a')])
    service    = WikiService.new(repository)
    assert_equal(%i[refreshed refreshed limited], 3.times.map { service.refresh('1.2.3.4') })
    assert_equal :refreshed, service.refresh('5.6.7.8')
    assert_equal [3, 3], [repository.sitemaps, repository.clears]
  end

  def test_the_whole_board_refreshes_ten_times_a_minute_at_most
    service = WikiService.new(Repository.new([page('/a')]))
    results = 12.times.map { |n| service.refresh("10.0.0.#{n}") }
    assert_equal ([:refreshed] * 10) + ([:limited] * 2), results
  end

  def test_a_refresh_the_wiki_does_not_answer_fails_quietly
    _, err = capture_io { assert_equal :failed, WikiService.new(Repository.new([], fail: true)).refresh('k') }
    assert_match(/refresh: WikiRepository::Error: HTTP 502/, err)
  end

  def test_a_refresh_the_board_refuses_does_not_count_against_the_caller
    service = WikiService.new(Repository.new([page('/a')]), board_refreshes: BBS::RateLimit.new(limit: 1, per: 60))
    assert_equal %i[refreshed limited], [service.refresh('1.2.3.4'), service.refresh('5.6.7.8')]
    caller_refreshes = BBS::RateLimit.new(limit: 1, per: 60)
    service = WikiService.new(Repository.new([page('/a')]), caller_refreshes: caller_refreshes,
                                                            board_refreshes: BBS::RateLimit.new(limit: 0, per: 60))
    assert_equal :limited, service.refresh('1.2.3.4')
    assert caller_refreshes.room?('1.2.3.4')
  end

  def test_a_page_comes_as_markdown_and_its_problems_too
    ok = WikiService.new(Repository.new([], page: { 'title' => 'T', 'markdown' => 'body' }))
    assert_equal "# T\n\nbody", ok.page_markdown(page('/a'))
    forbidden = WikiService.new(Repository.new([], page: { 'error' => 'forbidden' }))
    assert_match(/Forbidden/, forbidden.page_markdown(page('/a')))
    down = WikiService.new(Repository.new([], fail: true))
    _, err = capture_io { assert_match(/did not answer/, down.page_markdown(page('/a'))) }
    assert_match(%r{/a}, err)
  end
end
