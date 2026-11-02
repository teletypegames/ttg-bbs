# frozen_string_literal: true

# The rules of the posts: what a post may hold, who sees it, and what
# happens when it is first published. Readers see the published posts; the
# editors see all of them. What an editor typed is cleaned of control
# characters (BBS::Text.clean) before it is checked and kept.
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
  def create(author:, face: 'modern', **draft)
    draft   = clean(**draft)
    problem = check(**draft)
    return problem if problem

    saved { find(@repo.insert(**draft, face: PostModel::FACES.include?(face) ? face : 'modern', author_id: author.id)) }
  end

  # The PostModel as saved, or a Symbol naming what is wrong with it.
  def update(id, **draft)
    draft   = clean(**draft)
    problem = check(**draft)
    return problem if problem

    saved do
      @repo.update(id, **draft)
      find(id)
    end
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

  # The draft as it is kept: no control characters, the title and the
  # summary on one line and trimmed.
  def clean(title:, summary:, body:, category:)
    { title: BBS::Text.line(title), summary: BBS::Text.line(summary),
      body: BBS::Text.clean(body), category: category.to_s }
  end

  def check(title:, summary:, body:, category:)
    return :no_title if title.empty?
    return :long_title if title.length > MAX_TITLE
    return :long_summary if summary.length > MAX_SUMMARY
    return :long_body if body.bytesize > MAX_BODY
    return :bad_category unless @categories.listed?(category)

    nil
  end

  # The block's value; :not_saved, logged, when SQLite failed.
  def saved
    yield
  rescue SQLite3::Exception => e
    BBS.log('saving a post', e)
    :not_saved
  end

  # A listener that fails does not fail the post: it is saved already.
  def announce(post)
    @listeners.each do |listener|
      listener.call(post)
    rescue StandardError => e
      BBS.log('on_publish', e)
    end
  end
end
