# frozen_string_literal: true

WikiPageModel = Struct.new(:id, :path, :title, :description, :created_at, :locale, keyword_init: true)
