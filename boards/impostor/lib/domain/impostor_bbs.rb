# frozen_string_literal: true

# The board itself, whatever terminal a caller has. The debrief terminal and
# its code check live in the impostor gem (lib/impostor), which another rubbs
# BBS can mount as a door; the board gives it the record of its calls, kept
# by the domain (lib/domain). Both faces work on one instance of it.
class ImpostorBBS
  include Rubbs::Common::Board::Domain

  path :sessions, 'data/sessions.sqlite3'

  service(:debriefs) do
    Rubbs.log('sessions', "kept in #{sessions}")
    SessionService.new(SessionRepository.new(sessions).open!)
  end

  background('feedback export') { export_feedback }

  # Hands the feedback the board kept in its own record before the network's
  # (ttg-common TTG::Feedback, the +debrief+ kind) over to it once; a marker
  # file beside the database says it is done. Raises when the Central does
  # not take it (the background job tries again). Returns how many went.
  def export_feedback
    marker = "#{sessions}.feedback-exported"
    return 0 if File.exist?(marker)

    rows = debriefs.feedback_rows
    rows.each_slice(20) do |batch|
      answer = TTG::Feedback.box.call(:import, nil, rows: batch)
      raise "the Central did not take the feedback: #{answer['result']}" unless answer['result'] == 'ok'
    end
    File.write(marker, "#{Time.now.utc.iso8601} #{rows.size}\n")
    rows.size
  end
end
