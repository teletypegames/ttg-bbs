# frozen_string_literal: true

require 'bbs'
require 'json'
require 'kramdown'
require 'kramdown-parser-gfm'
require 'webrick'
require_relative '../ui/petscii'

module Web
  # The blog read over HTTP, for teletypegames.org: JSON, read only, on the
  # inner network of the server (interstack), never on a public port. It runs
  # in the board's process, beside the telnet line, on the same TTGBlogBBS. Only
  # the published posts: an unpublished one is the editors' business.
  #
  #   GET /health              {"ok":true}
  #   GET /categories          the categories, with their post counts
  #   GET /posts[?limit=N]     the posts newest first, without their bodies
  #   GET /posts/SLUG          one post: its Markdown, its HTML, its C64 screen
  class Api
    MAX_LIMIT = 200

    def initialize(bbs, port:, host: '0.0.0.0')
      @bbs    = bbs
      @posts  = bbs.posts
      @server = WEBrick::HTTPServer.new(BindAddress: host, Port: port, Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
                                        AccessLog: [])
      @server.mount_proc('/') { |req, res| serve(req, res) }
    end

    def start = Thread.new { @server.start }

    def self.html(markdown) = Kramdown::Document.new(markdown.to_s, input: 'GFM', hard_wrap: false).to_html

    private

    def serve(req, res)
      status, body = req.request_method == 'GET' ? route(req) : [405, { error: 'read only' }]
      res.status = status
      res['Content-Type'] = 'application/json; charset=utf-8'
      res.body = JSON.generate(body)
    rescue StandardError => e
      warn "ttgblog web: #{e.class}: #{e.message}"
      res.status = 500
      res.body = JSON.generate(error: 'internal error')
    end

    # WEBrick reads the path as bytes; SQLite would bind them as a BLOB,
    # which never equals the TEXT of a slug.
    def route(req)
      case String.new(req.path, encoding: Encoding::UTF_8)
      when '/health'     then [200, { ok: true }]
      when '/categories' then [200, { categories: categories }]
      when '/posts'      then [200, { posts: @posts.all(limit: limit(req), published: true).map { |p| summary(p) } }]
      when %r{\A/posts/([a-z0-9-]+)\z}
        post = @posts.find_by_slug(Regexp.last_match(1))
        post&.published ? [200, full(post)] : [404, { error: 'no such post' }]
      else [404, { error: 'not found' }]
      end
    end

    def limit(req)
      n = req.query['limit'].to_i
      n.positive? ? [n, MAX_LIMIT].min : nil
    end

    def categories
      @bbs.categories.all.map { |c| { id: c.id, name: c.name, about: c.about, count: @posts.count(c.id, published: true) } }
    end

    def summary(post)
      category = @bbs.categories.find(post.category)
      { id: post.id, slug: post.slug, title: post.title, summary: post.summary,
        category: { id: category.id, name: category.name }, author: post.author, face: post.face,
        published_at: post.published_at&.utc&.iso8601, created_at: post.created_at.utc.iso8601,
        updated_at: post.updated_at.utc.iso8601, updated: post.updated? }
    end

    def full(post)
      summary(post).merge(body: post.body, html: Api.html(post.body),
                          screen: { cols: UI::Petscii::COLS, page: UI::Petscii::PAGE,
                                    lines: UI::Petscii.post_screen(@bbs, post) })
    end
  end
end
