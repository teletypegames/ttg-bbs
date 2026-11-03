# frozen_string_literal: true

require 'test_helper'
require 'bbs/test'
require_relative '../lib/ui/modern'
require_relative '../lib/ui/petscii'

# Both faces on a line without a socket: the menus, a post, a login.
class FaceTest < Minitest::Test
  include TestHelper

  def published(title)
    post = blog.posts.create(author: editor, **draft(title: title))
    blog.posts.set_published(post.id, true)
    post
  end

  def call(face, *keys, petscii: false)
    session = BBS::Test::Session.new(keys: keys, petscii: petscii)
    face.new(session, {}, blog).run
    BBS::FrameBuffer.plain(session.output)
  end

  def test_the_modern_menu_opens_a_post_by_its_number
    post   = published('Hello world')
    screen = call(UI::Modern, 'g', *post.id.to_s.chars, :enter, :enter, 'q')
    assert_includes screen, 'news from teletype games'
    assert_includes screen, 'GO TO POST'
    assert_includes screen, 'Hello world'
  end

  def test_a_number_without_a_post_is_told
    assert_includes call(UI::Modern, 'g', '9', :enter, ' ', 'q'), 'No post number 9.'
  end

  def test_an_editor_logs_in_and_gets_the_editors_menu
    editor('ed', 'secret-pass')
    screen = call(UI::Modern, 'e', *'ed'.chars, :enter, *'secret-pass'.chars, :enter, ' ', 'q')
    assert_includes screen, 'Welcome, ed.'
    assert_includes screen, 'write a post'
  end

  def test_the_c64_front_page_lists_the_newest_posts
    published('On the C64')
    screen = call(UI::Petscii, 'q', petscii: true)
    assert_includes screen, 'On the C64'
    assert_includes screen, 'editor login'
  end
end
