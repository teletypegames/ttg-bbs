# frozen_string_literal: true

require 'test_helper'

# The drafts: kept unchecked while an editor writes, seen only by the
# composer, and saved into their post or thrown away.
class DraftTest < Minitest::Test
  include TestHelper

  def author = @author ||= editor

  def autosave(id = nil, original: nil, **fields)
    blog.posts.autosave(id, author: author, face: 'petscii', original: original, **draft(**fields))
  end

  def published_post
    post = blog.posts.create(author: author, **draft)
    blog.posts.set_published(post.id, true)
  end

  def test_an_autosave_writes_a_draft_then_keeps_writing_the_same_one
    id = autosave(title: 'First')
    assert_equal id, autosave(id, title: 'Second')
    draft = blog.posts.find_draft(id)
    assert_equal ['Second', 'draft', nil, 'petscii', nil], [draft.title, draft.status, draft.original_id, draft.face, draft.slug]
  end

  def test_a_draft_is_kept_unchecked
    id = autosave(title: '', category: '')
    assert_equal ['', ''], blog.posts.find_draft(id).fields.values_at(:title, :category)
  end

  def test_the_lists_and_counts_leave_the_drafts_out
    post = published_post
    autosave(title: 'New')
    autosave(original: post, title: 'Edit')
    assert_equal [post.id], blog.posts.all.map(&:id)
    assert_equal [1, 1, 0], [blog.posts.total, blog.posts.count(category), blog.posts.total(published: false)]
  end

  def test_only_the_composer_finds_a_draft
    post    = published_post
    new_id  = autosave(title: 'New')
    edit_id = autosave(original: post, title: 'Edit')
    assert_equal([nil, nil], [new_id, edit_id].map { |id| blog.posts.find(id) })
    assert_equal [new_id], blog.posts.drafts.map(&:id)
    assert_equal [edit_id], blog.posts.drafts(post).map(&:id)
  end

  def test_a_new_post_draft_becomes_the_post_keeping_its_id
    id   = autosave(title: 'Brand new')
    post = blog.posts.commit(id)
    assert_equal [id, 'unpublished', 'Brand new'], [post.id, post.status, post.title]
    assert_match(/\A\d{4}-\d\d-\d\d-brand-new\z/, post.slug)
    assert_empty blog.posts.drafts
  end

  def test_an_edit_draft_is_written_into_its_post_and_goes
    post = published_post
    id   = autosave(original: post, title: 'Edited', body: 'new body')
    saved = blog.posts.commit(id)
    assert_equal [post.id, 'Edited', 'new body', post.slug, 'published'],
                 [saved.id, saved.title, saved.body, saved.slug, saved.status]
    assert_equal post.published_at, saved.published_at
    assert_nil blog.posts.find_draft(id)
  end

  def test_a_draft_that_does_not_pass_stays
    id = autosave(title: '')
    assert_equal :no_title, blog.posts.commit(id)
    refute_nil blog.posts.find_draft(id)
  end

  def test_an_original_saved_meanwhile_is_a_conflict_unless_forced
    post  = published_post
    mine  = autosave(original: post, title: 'Mine')
    other = autosave(original: post, title: 'Theirs')
    sleep 1.1
    assert_equal 'Theirs', blog.posts.commit(other).title
    assert_equal :conflict, blog.posts.commit(mine)
    assert_equal 'Theirs', blog.posts.find(post.id).title
    assert_equal 'Mine', blog.posts.commit(mine, force: true).title
  end

  def test_a_discarded_draft_is_gone_and_an_autosave_after_writes_a_new_one
    id = autosave
    assert_equal 1, blog.posts.discard(id)
    assert_equal 0, blog.posts.discard(id)
    refute_nil blog.posts.find_draft(autosave(id, title: 'Again'))
  end

  def test_deleting_a_post_takes_its_drafts
    post = published_post
    id   = autosave(original: post)
    blog.posts.delete(post.id)
    assert_nil blog.posts.find_draft(id)
  end

  def test_an_autosave_that_fails_is_logged_not_raised
    post = published_post
    blog.posts.delete(post.id)
    _, err = capture_io { assert_nil autosave(original: post) }
    assert_match(/autosave/, err)
  end
end
