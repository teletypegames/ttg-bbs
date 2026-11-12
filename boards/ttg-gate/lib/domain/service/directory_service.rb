# frozen_string_literal: true

# The menu of the gate: the boards a caller can dial.
class DirectoryService
  def initialize(boards)
    @boards = boards
  end

  # The enabled boards, in the order of the file; on a C64 (+petscii+) only
  # those that have a PETSCII face. A board with a role is only for the
  # caller signed in as +identity+ with that role; without an identity (the
  # counts of Today) it is left out.
  def boards(petscii: false, identity: nil)
    @boards.all.select { |b| b.enabled? && (!petscii || b.petscii?) && b.for?(identity) }
  end
end
