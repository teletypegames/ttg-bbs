# frozen_string_literal: true

# The rules of the posts: what a post may hold, who sees it, and what
# happens when it is first published. Readers see the published posts; the
# editors see all of them.
class PostService
  MAX_TITLE   = 80
  MAX_SUMMARY = 280
  MAX_BODY    = 64 * 1024

  def initialize(repo, categories:)
    @repo       = repo
    @categories = categories
    @listeners  = []
  end

  # The block is called with a post the first time it is published.
  def on_publish(&block) = @listeners << block

  # Posts newest first, all of them or one category's; without their bodies.
  # +published+ true or false keeps only the published or the unpublished
  # ones; nil keeps both.
  def all(category: nil, limit: nil, published: nil) = @repo.all(category: category, limit: limit, published: published)

  def total(published: nil) = @repo.count(published: published)

  def count(category, published: nil) = @repo.count(category: category, published: published)

  def find(id) = @repo.find(id)

  def find_by_slug(slug) = @repo.find_by_slug(slug)

  # The new, unpublished PostModel, or a Symbol naming what is wrong with it.
  def create(author:, title:, summary:, body:, category:, face: 'modern')
    problem = check(title, summary, body, category)
    return problem if problem

    id = @repo.insert(title: title.strip, summary: summary.strip, body: body, category: category,
                      face: PostModel::FACES.include?(face) ? face : 'modern', author_id: author.id)
    id ? find(id) : :not_saved
  end

  # The PostModel as saved, or a Symbol naming what is wrong with it.
  def update(id, title:, summary:, body:, category:)
    problem = check(title, summary, body, category)
    return problem if problem
    return :not_saved unless @repo.update(id, title: title.strip, summary: summary.strip, body: body, category: category)

    find(id)
  end

  # The post published or taken back, as it is now; nil when there is no
  # such post. The first publishing tells the listeners; taking it back and
  # publishing it again does not.
  def set_published(id, published)
    first = @repo.set_published(id, published)
    return nil if first.nil?

    post = find(id)
    announce(post) if first
    post
  end

  def delete(id) = @repo.delete(id)

  private

  def check(title, summary, body, category)
    return :no_title if title.to_s.strip.empty?
    return :long_title if title.length > MAX_TITLE
    return :long_summary if summary.to_s.length > MAX_SUMMARY
    return :long_body if body.to_s.bytesize > MAX_BODY
    return :bad_category unless @categories.listed?(category)

    nil
  end

  # A listener that fails does not fail the post: it is saved already.
  def announce(post)
    @listeners.each do |listener|
      listener.call(post)
    rescue StandardError => e
      warn "ttgblog: on_publish failed: #{e.class}: #{e.message}"
    end
  end
end
