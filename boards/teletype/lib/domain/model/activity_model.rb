# frozen_string_literal: true

# One entry of the Gitea activity feed. +commits+ are [sha, message] pairs.
ActivityModel = Struct.new(:kind, :user, :repo, :ref, :created_at, :commits, :title, keyword_init: true)
