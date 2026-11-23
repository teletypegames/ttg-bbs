# frozen_string_literal: true

# The sysops' note of an upload to the Exhibition: a feedback of the board's
# own kind (KIND) on the network's feedback box (ttg-common TTG::Feedback,
# on TTG Gate BBS), sent as the uploader. The Central posts its Discord line
# (the board, the kind, who; never the text) and the sysops' desk keeps the
# title, the work's id and the command that takes it down. A note that does
# not go (the Central away, the uploader's feedback limit reached) is logged
# and costs the work nothing.
class UploadNoteService
  KIND = 'upload'

  # A note sender on +box+ (a Rubbs::Common::Central::Proxy; the network's
  # feedback box when nil).
  def initialize(box = nil)
    @box = box
  end

  # Sends the note of WorkModel +work+ by +actor+ (a
  # Rubbs::Common::Central::Actor). Returns the Central's answer.
  def call(work, actor)
    answer = box.call(
      :submit,
      actor,
      kind:    KIND,
      subject: "New PETSCII work: #{work.title}"[0, 60],
      body:    body(work),
      context: "Exhibition work #{work.id}"
    )
    result = answer['result'].to_s
    Rubbs.log('exhibition', 'upload note not sent', level: :warn, work: work.id, result: result) unless result == 'ok'
    answer
  end

  private

  def box = @box || TTG::Feedback.box

  def body(work)
    picture = work.petscii
    "\"#{work.title}\" by #{work.handle} went on the Exhibition of Pixelia BBS (#{picture.charset} case set, " \
      "background #{ColorModel[picture.background].name}, border #{ColorModel[picture.border].name}). " \
      "If it does not belong there: docker exec -w /app/boards/pixelia ttg-bbs bin/works remove #{work.id}"
  end
end
