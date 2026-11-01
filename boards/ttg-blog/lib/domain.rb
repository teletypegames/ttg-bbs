# frozen_string_literal: true

require_relative 'domain/model/category_model'
require_relative 'domain/model/user_model'
require_relative 'domain/model/post_model'
require_relative 'domain/repository/sqlite_database'
require_relative 'domain/repository/category_repository'
require_relative 'domain/repository/user_repository'
require_relative 'domain/repository/post_repository'
require_relative 'domain/service/category_service'
require_relative 'domain/service/editor_service'
require_relative 'domain/service/post_service'
require_relative 'domain/service/discord_notifier'
require_relative 'domain/ttg_blog_bbs'
