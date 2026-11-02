# frozen_string_literal: true

require 'test_helper'
require_relative '../lib/ui/modern'
require_relative '../lib/ui/petscii'
require_relative '../lib/web/api'

# Web::Api, the read API teletypegames.org reads: its routes, without a
# socket.
class ApiTest < Minitest::Test
  include TestHelper

  Request = Struct.new(:request_method, :path, :query)

  def get(path, query = {})
    @api ||= Web::Api.new(blog, port: 0, host: '127.0.0.1')
    status, body = @api.send(:route, Request.new('GET', path, query))
    [status, JSON.parse(JSON.generate(body))]
  end

  def publish(count)
    author = editor
    count.times do |i|
      post = blog.posts.create(author: author, **draft(title: "Post #{i}"))
      blog.posts.set_published(post.id, true)
    end
  end

  def test_posts_come_newest_first_in_the_fields_the_site_reads
    publish(2)
    status, body = get('/posts')
    assert_equal 200, status
    post = body['posts'].first
    assert_equal %w[author category created_at face id published_at slug summary title updated updated_at], post.keys.sort
    assert_equal({ 'id' => category, 'name' => 'News' }, post['category'])
  end

  def test_drafts_never_reach_the_web
    publish(1)
    blog.posts.autosave(nil, author: editor('other', 'other-pass'), face: 'modern', **draft(title: 'Draft'))
    assert_equal 1, get('/posts').last['posts'].size
    assert_equal(1, get('/categories').last['categories'].sum { |c| c['count'] })
  end

  def test_posts_are_capped_by_default_and_at_most
    publish(Web::Api::MAX_LIMIT + 1)
    assert_equal Web::Api::DEFAULT_LIMIT, get('/posts').last['posts'].size
    assert_equal 1, get('/posts', 'limit' => '1').last['posts'].size
    assert_equal Web::Api::MAX_LIMIT, get('/posts', 'limit' => '500').last['posts'].size
  end

  def test_one_post_has_its_markdown_html_and_c64_screen
    publish(1)
    slug = blog.posts.all.first.slug
    status, post = get("/posts/#{slug}")
    assert_equal 200, status
    assert_includes post['html'], '<h1'
    assert_equal UI::Petscii::COLS, post['screen']['cols']
  end

  def test_an_unpublished_post_is_not_there
    post = blog.posts.create(author: editor, **draft)
    assert_equal 404, get("/posts/#{post.slug}").first
  end

  def test_categories_count_the_published_posts
    publish(2)
    news = get('/categories').last['categories'].find { |c| c['id'] == category }
    assert_equal 2, news['count']
  end
end
