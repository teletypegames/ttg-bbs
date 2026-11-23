# frozen_string_literal: true

# The Exhibition: the canvas saved as a work under a title and a handle, a
# PETSCII picture uploaded from TTG Canvas 64 hung the same way, the works
# newest first, and their removal (the admin script's moderation). A caller
# (Rubbs::Common::Line::RateLimit.caller_key: an address, not a session, so calling again
# does not help) hangs at most one work in +cooldown+ seconds, and the whole
# board at most +per_hour+ an hour, saves and uploads counted together. Both
# limits are checked together and a work counts in both only once it is on
# the exhibition, so a failed write costs no turn.
#
# An upload is judged before anything is written (#accept): at most
# MAX_UPLOAD bytes, a .tcv file by its FORMAT.md, hires with a ROM character
# set (multicolour and custom sets are game graphics a terminal cannot show),
# not blank. Every uploaded work goes to +notify+ (a callable given the work
# and the uploader's Rubbs::Common::Central::Actor), the sysops' note.
class ExhibitionService
  MAX_TITLE  = 32
  MAX_HANDLE = 16
  BOARD      = :board
  # The largest upload taken: a custom-set picture with a load address,
  # padded to a 1 KiB XMODEM block, so even that is read and refused in words.
  MAX_UPLOAD = 5 * 1024

  # Why an upload is not taken: +reason+ (:broken, :game_graphics, :blank),
  # and for a broken file the reader's +detail+.
  Refusal = Data.define(:reason, :detail)

  def initialize(works, canvas:, cooldown: 300, per_hour: 30, notify: nil)
    @works   = works
    @canvas  = canvas
    @notify  = notify
    @callers = Rubbs::Common::Line::RateLimit.new(limit: 1, per: cooldown)
    @board   = Rubbs::Common::Line::RateLimit.new(limit: per_hour, per: 3600)
    @lock    = Mutex.new
  end

  def all = @works.all

  def find(id) = @works.find(id)

  def remove(id) = @works.remove(id)

  # Saves the canvas as it is now for the caller +key+: the WorkModel, or
  # :no_title, :no_handle, :blank_canvas, :too_soon or :failed.
  def save(key, title:, handle:)
    title  = clean(title, MAX_TITLE)
    handle = clean(handle, MAX_HANDLE)
    return :no_title if title.empty?
    return :no_handle if handle.empty?

    canvas = @canvas.snapshot
    return :blank_canvas if canvas.empty?

    @lock.synchronize { add(key, title: title, handle: handle, canvas: canvas) }
  end

  # The PetsciiModel of an uploaded file +data+, or a Refusal.
  def accept(data)
    return Refusal.new(:broken, "it is larger than #{MAX_UPLOAD} bytes") if data.bytesize > MAX_UPLOAD

    tcv = TcvModel.parse(data)
    return Refusal.new(:game_graphics, nil) unless tcv.hires? && !tcv.custom_charset?

    picture = PetsciiModel.from_tcv(tcv)
    picture.empty? ? Refusal.new(:blank, nil) : picture
  rescue TcvModel::FormatError => e
    Refusal.new(:broken, e.message)
  end

  # Hangs the PetsciiModel +picture+ (from #accept) for the caller +key+, by
  # +actor+ (for the note): the WorkModel, or :no_title, :no_handle,
  # :too_soon or :failed.
  def hang(key, title:, handle:, picture:, actor: nil)
    title  = clean(title, MAX_TITLE)
    handle = clean(handle, MAX_HANDLE)
    return :no_title if title.empty?
    return :no_handle if handle.empty?

    work = @lock.synchronize { add(key, title: title, handle: handle, petscii: picture) }
    @notify&.call(work, actor) if work.is_a?(WorkModel)
    work
  end

  # Seconds until the caller +key+ may save again; 0 when now.
  def wait(key) = [@callers.wait(key), @board.wait(BOARD)].max.ceil

  # +text+ on one line without control or invisible format characters, its
  # spaces squeezed, at most +max+ characters long.
  def clean(text, max) = Rubbs::Common::Text.line(text).gsub(/\p{Cf}/, '').squeeze(' ').strip[0, max].strip

  private

  # Under the lock, so that no other save comes between the check and the
  # count.
  def add(key, **work)
    limits = [[@callers, key], [@board, BOARD]]
    return :too_soon unless limits.all? { |limit, k| limit.room?(k) }

    work = @works.add(**work) or return :failed
    limits.each { |limit, k| limit.record(k) }
    work
  end
end
