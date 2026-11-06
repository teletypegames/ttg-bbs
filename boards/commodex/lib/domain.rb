# frozen_string_literal: true

require 'rubbs'

require_relative 'domain/migrations'

require_relative 'domain/model/game_model'
require_relative 'domain/model/tip_model'
require_relative 'domain/model/summary_model'
require_relative 'domain/repository/wikidata_repository'
require_relative 'domain/repository/wikipedia_repository'
require_relative 'domain/repository/tip_seed_repository'
require_relative 'domain/service/catalog_service'
require_relative 'domain/service/about_service'
require_relative 'domain/service/tip_service'
require_relative 'domain/commodex_bbs'
