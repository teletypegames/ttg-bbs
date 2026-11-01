# frozen_string_literal: true

require 'test_helper'

# PostService: what a post may hold, who sees it, and the first publishing.
class PostServiceTest < Minitest::Test
  include TestHelper

  def test_control_characters_never_reach_the_database
    post = blog.posts.create(author: editor, **draft(title: "Hi\e[2J‮there\n", summary: "a\rb\u0085",
                                                     body: "one\n\e]0;x\atwo"))
    assert_equal ['Hi[2Jthere', 'ab', "one\n]0;xtwo"], [post.title, post.summary, post.body]
  end

  def test_a_post_is_checked_before_it_is_kept
    author = editor
    assert_equal :no_title, blog.posts.create(author: author, **draft(title: " \e "))
    assert_equal :long_title, blog.posts.create(author: author, **draft(title: 'x' * 81))
    assert_equal :bad_category, blog.posts.create(author: author, **draft(category: 'nope'))
    assert_equal 0, blog.posts.total
  end

  def test_readers_see_only_published_posts
    post = blog.posts.create(author: editor, **draft)
    assert_empty blog.posts.all(published: true)
    blog.posts.set_published(post.id, true)
    assert_equal [post.id], blog.posts.all(published: true).map(&:id)
  end

  def test_only_the_first_publishing_is_announced
    told = []
    blog.posts.on_publish { |p| told << p.id }
    post = blog.posts.create(author: editor, **draft)
    blog.posts.set_published(post.id, true)
    blog.posts.set_published(post.id, false)
    blog.posts.set_published(post.id, true)
    assert_equal [post.id], told
  end

  def test_an_edit_keeps_the_slug
    post = blog.posts.create(author: editor, **draft)
    edited = blog.posts.update(post.id, **draft(title: 'Another title'))
    assert_equal ['Another title', post.slug], [edited.title, edited.slug]
  end
end
