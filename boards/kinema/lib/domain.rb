# frozen_string_literal: true

require 'rubbs'

require_relative 'domain/migrations'

require_relative 'domain/model/catalog_film_model'
require_relative 'domain/model/catalog_model'
require_relative 'domain/model/hit_model'
require_relative 'domain/model/film_model'
require_relative 'domain/model/person_model'
require_relative 'domain/model/article_model'
require_relative 'domain/model/rating_model'
require_relative 'domain/model/mark_model'
require_relative 'domain/repository/catalog_repository'
require_relative 'domain/repository/wikidata_repository'
require_relative 'domain/repository/wikipedia_repository'
require_relative 'domain/service/catalog_service'
require_relative 'domain/service/film_service'
require_relative 'domain/service/rating_service'
require_relative 'domain/kinema_bbs'
