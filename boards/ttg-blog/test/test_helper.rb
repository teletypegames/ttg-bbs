# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/domain'
require 'bbs/test'

# What the tests share: a blog on a throwaway database (BBS::Test.database,
# the models bound to it and TTG_BLOG_BBS_DB its file), a temporary
# folder, and the editors as accounts of the network (BBS::Auth).
module TestHelper
  CATEGORIES = File.expand_path('../config/categories.yml', __dir__)

  ENV_NAMES = %w[TTG_BLOG_BBS_DB TTG_BLOG_BBS_CATEGORIES].freeze

  def setup
    @dir = Dir.mktmpdir('ttg-blog-bbs-test')
    @db  = BBS::Test.database(MIGRATIONS)
    with_env(db_path, CATEGORIES)
  end

  def teardown
    BBS.config.auth = nil
    ENV_NAMES.each { |name| ENV.delete(name) }
    FileUtils.remove_entry(@dir)
  end

  def with_env(db, categories) = ENV.update(ENV_NAMES.zip([db, categories]).to_h)

  def db_path = @db.opts[:database]

  # The blog as BBS.board starts it: its databases opened, the models
  # bound to them.
  def blog = @blog ||= TTGBlogBBS.new.tap(&:databases)

  def category = blog.categories.all.first.id

  # The accounts of the network for the test (BBS::Test.accounts), the
  # board's login (BBS.config.auth) on them.
  def accounts
    @accounts ||= BBS::Test.accounts(roles: %w[member]).tap do |directory|
      BBS.config.auth = BBS::Auth::Setup.new(directory: directory, login: :menu, guests: true)
    end
  end

  # An editor: an account of the network with the blogger role, its Identity.
  def editor(name = 'tasi', password = 'secret-pass')
    accounts.register(name, password)
    accounts.grant(name, :blogger)
    accounts.find(name)
  end

  def draft(**fields) = { title: 'Hello world', summary: 'A first post', body: "# Hi\n\nthere", category: category }.merge(fields)
end
