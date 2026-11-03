# frozen_string_literal: true

# The blog itself, whatever terminal a caller has: its services wired to the
# SQLite file (BlogSchema) and the category list, and Discord rung when a
# post is first published. Both faces (lib/ui/modern, lib/ui/petscii), the
# read API (lib/web) and bin/user work on one instance of it.
class TTGBlogBBS
  include BBS::Domain

  setting :http_port, 8080
  setting :autosave_seconds, 15
  setting :site_url, 'https://teletypegames.org'
  setting :discord_webhook, ''
  path    :db, 'data/ttgblog.sqlite3'
  path    :categories_file, 'config/categories.yml', env: 'CATEGORIES'

  service(:categories) { CategoryService.new(CategoryRepository.new(categories_file)) }
  service(:editors)    { EditorService.new(UserRepository.new(store), guard: LoginGuard.new(store: store)) }
  service(:posts)      { PostService.new(PostRepository.new(store), categories: categories).tap { |posts| announce(posts) } }

  # Where a published post is on the web.
  def post_url(post) = "#{site_url.chomp('/')}/blog/#{post.slug}"

  private

  def store = @store ||= database(db, BlogSchema)

  def announce(posts)
    return if discord_webhook.empty?

    discord = DiscordNotifier.new(webhook: discord_webhook, site: site_url)
    posts.on_publish { |post| discord.call(post) }
  end
end
