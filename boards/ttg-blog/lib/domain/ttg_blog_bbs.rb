# frozen_string_literal: true

# The blog itself, whatever terminal a caller has: its services wired to the
# SQLite file and the category list, and Discord rung when a post is first
# published. Both faces (lib/ui/modern, lib/ui/petscii), the read API
# (lib/web) and bin/user work on one instance of it.
class TTGBlogBBS
  ROOT = File.expand_path('../..', __dir__)

  attr_reader :posts, :editors, :categories, :http_port

  def initialize
    db          = SqliteDatabase.new(ENV.fetch('TTG_BLOG_BBS_DB', File.join(ROOT, 'data/ttgblog.sqlite3')))
    @categories = CategoryService.new(CategoryRepository.new(ENV.fetch('TTG_BLOG_BBS_CATEGORIES',
                                                                       File.join(ROOT, 'config/categories.yml'))))
    @editors    = EditorService.new(UserRepository.new(db))
    @posts      = PostService.new(PostRepository.new(db), categories: @categories)
    @http_port  = ENV.fetch('TTG_BLOG_BBS_HTTP_PORT', '8080').to_i

    webhook = ENV['TTG_BLOG_BBS_DISCORD_WEBHOOK'].to_s
    return if webhook.empty?

    discord = DiscordNotifier.new(webhook: webhook, site: ENV.fetch('TTG_BLOG_BBS_SITE_URL', 'https://teletypegames.org'))
    @posts.on_publish { |post| discord.call(post) }
  end

  # The services by name.
  def services = { posts: @posts, editors: @editors, categories: @categories }
end
