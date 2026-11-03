# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/domain'

# What the tests share: a blog on a database in a temporary folder, and
# the editors' digests cheap to derive.
module TestHelper
  CATEGORIES = File.expand_path('../config/categories.yml', __dir__)

  ENV_NAMES = %w[TTG_BLOG_BBS_DB TTG_BLOG_BBS_CATEGORIES].freeze

  def setup
    @dir = Dir.mktmpdir('ttg-blog-bbs-test')
    with_env(db_path, CATEGORIES)
  end

  def teardown
    ENV_NAMES.each { |name| ENV.delete(name) }
    FileUtils.remove_entry(@dir)
  end

  def with_env(db, categories) = ENV.update(ENV_NAMES.zip([db, categories]).to_h)

  def db_path = File.join(@dir, 'ttgblog.sqlite3')

  def blog = @blog ||= TTGBlogBBS.new

  def category = blog.categories.all.first.id

  def editor(name = 'tasi', password = 'secret-pass')
    blog.editors.add(name, password)
    blog.editors.login(name, password, caller: 'test')
  end

  def draft(**fields) = { title: 'Hello world', summary: 'A first post', body: "# Hi\n\nthere", category: category }.merge(fields)
end
