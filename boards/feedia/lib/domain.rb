# frozen_string_literal: true

require 'bbs'

require_relative 'domain/model/html_text'
require_relative 'domain/model/feed_model'
require_relative 'domain/model/item_model'
require_relative 'domain/model/channel_model'
require_relative 'domain/model/message_model'
require_relative 'domain/model/feed_xml'
require_relative 'domain/repository/feed_list_repository'
require_relative 'domain/repository/feed_repository'
require_relative 'domain/repository/inbox_repository'
require_relative 'domain/repository/discord_repository'
require_relative 'domain/service/feed_service'
require_relative 'domain/service/inbox_service'
require_relative 'domain/feedia_bbs'
