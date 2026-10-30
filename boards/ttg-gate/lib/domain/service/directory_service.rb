# frozen_string_literal: true

# The menu of the gate: the boards a caller can dial.
class DirectoryService
  def initialize(boards)
    @boards = boards
  end

  # The enabled boards, in the order of the file; on a C64 (+petscii+) only
  # those that have a PETSCII face.
  def boards(petscii: false)
    @boards.all.select { |b| b.enabled? && (!petscii || b.petscii?) }
  end
end
