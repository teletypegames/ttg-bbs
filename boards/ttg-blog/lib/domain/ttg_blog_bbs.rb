# frozen_string_literal: true

# The blog itself, whatever terminal a caller has: its services on the
# SQLite file (MIGRATIONS, the models) and the category list. Both faces (lib/ui/modern, lib/ui/petscii) and the
# read API (lib/web) work on one instance of it. The editors are the accounts
# of the network with the blogger role (Rubbs::Common::Auth, kept on TTG Gate BBS).
class TTGBlogBBS
  include Rubbs::Common::Board::Domain

  setting :http_port, 8080
  setting :autosave_seconds, 15
  setting :site_url, 'https://teletypegames.org'
  path    :db, 'data/ttgblog.sqlite3'
  path    :categories_file, 'config/categories.yml', env: 'CATEGORIES'
  database :db, MIGRATIONS

  service(:categories) { CategoryService.new(CategoryRepository.new(categories_file)) }
  service(:posts)      { PostService.new(categories: categories) }

  # Where a published post is on the web.
  def post_url(post) = "#{site_url.chomp('/')}/blog/#{post.slug}"
end
