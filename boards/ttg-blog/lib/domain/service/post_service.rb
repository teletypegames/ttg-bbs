# frozen_string_literal: true

# The rules of the posts: what a post may hold, who sees it, and what
# happens when it is first published. Readers see the published posts; the
# editors see all of them; the drafts only the composer does. What an
# editor typed is cleaned of control characters (BBS::Text.clean) before it
# is checked and kept; a draft is kept unchecked.
class PostService
  MAX_TITLE   = 80
  MAX_SUMMARY = 280
  MAX_BODY    = 64 * 1024

  def initialize(categories:)
    @categories = categories
    @listeners  = []
  end

  # The block is called with a post the first time it is published.
  def on_publish(&block) = @listeners << block

  # Posts newest first, all of them or one category's; without their bodies.
  # +published+ true or false keeps only the published or the unpublished
  # ones; nil keeps both.
  def all(category: nil, limit: nil, published: nil) = PostModel.newest(category: category, limit: limit, published: published)

  def total(published: nil) = PostModel.count_of(published: published)

  def count(category, published: nil) = PostModel.count_of(category: category, published: published)

  def find(id) = PostModel.find_post(id)

  def find_by_slug(slug) = PostModel.find_by_slug(slug)

  # The new, unpublished PostModel, or a Symbol naming what is wrong with it.
  def create(author:, face: 'modern', **draft)
    draft   = clean(**draft)
    problem = check(**draft)
    return problem if problem

    saved { find(PostModel.add(**draft, face: PostModel::FACES.include?(face) ? face : 'modern', author_id: author.id)) }
  end

  # The PostModel as saved, or a Symbol naming what is wrong with it.
  def update(id, **draft)
    draft   = clean(**draft)
    problem = check(**draft)
    return problem if problem

    saved do
      PostModel.edit(id, **draft)
      find(id)
    end
  end

  # The post published or taken back, as it is now; nil when there is no
  # such post. The first publishing tells the listeners; taking it back and
  # publishing it again does not.
  def set_published(id, published)
    first = PostModel.set_published(id, published)
    return nil if first.nil?

    post = find(id)
    announce(post) if first
    post
  end

  def delete(id) = PostModel.remove(id)

  # The drafts of +post+ (a PostModel), or of new posts for nil, the last
  # written first, with their bodies.
  def drafts(post = nil) = PostModel.drafts(post&.id)

  def find_draft(id) = PostModel.find_draft(id)

  # Keeps what an editor is writing, unchecked, so a hang-up or a closed
  # window loses nothing: into draft +id+, or a new one for nil (and when
  # it was discarded meanwhile). +original+ is the PostModel being edited,
  # nil for a new post. The id of the draft; nil, logged, when it could not
  # be kept: the editing goes on.
  def autosave(id, author:, face:, original: nil, **fields)
    kept = PostModel.save_draft(id, clean(**fields), original_id: original&.id, author_id: author.id,
                                              face: PostModel::FACES.include?(face) ? face : 'modern',
                                              base_updated_at: original && original.updated_at.utc.iso8601)
    BBS.log('autosave', "post #{original.id} is gone") unless kept
    kept
  rescue Sequel::DatabaseError => e
    BBS.log('autosave', e)
    nil
  end

  # Saves draft +id+ (see PostModel.commit_draft): its post as it is
  # now, or a Symbol naming what is wrong (the draft stays then):
  # :conflict when the original was saved since the edit began and
  # +force+ is false, :gone when the draft or its original is gone, or
  # what #check finds.
  def commit(id, force: false)
    draft = PostModel.find_draft(id)
    return :gone unless draft

    problem = check(**draft.fields)
    return problem if problem

    saved do
      result = PostModel.commit_draft(id, force: force)
      result.is_a?(Symbol) ? result : find(result)
    end
  end

  # Throws draft +id+ away; the number of drafts thrown away (0 or 1).
  def discard(id) = PostModel.discard(id)

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
  rescue Sequel::DatabaseError => e
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
