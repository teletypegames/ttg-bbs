# frozen_string_literal: true

WikiPage = Struct.new(:id, :path, :title, :description, :created_at, :locale, keyword_init: true)
