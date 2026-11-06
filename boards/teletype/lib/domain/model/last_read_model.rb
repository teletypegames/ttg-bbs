# frozen_string_literal: true

# How far a registered name had read each message board before the
# network's wall took their place: the board's message count when the
# name last opened it. Nothing reads or writes it any more; the table is
# kept as it was, with the posts it counted (PostModel).
class LastReadModel < Rubbs::Common::Storage::Model
  table :last_read
end
