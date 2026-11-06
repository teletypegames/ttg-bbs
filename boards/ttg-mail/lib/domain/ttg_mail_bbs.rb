# frozen_string_literal: true

# The board itself, whatever terminal a caller has. TTG Mail BBS keeps nothing of its own:
# the letters, the accounts, the wall and the feedback live on TTG Gate BBS, the network's
# Central (ttg-common TTG::PrivateMessage, TTG::Wall, TTG::Feedback), and both faces ask it.
class TTGMailBBS
  include Rubbs::Common::Board::Domain

  service(:mail) { MailService.new(-> { TTG::PrivateMessage.mail }, -> { TTG::Wall.walls }) }
end
