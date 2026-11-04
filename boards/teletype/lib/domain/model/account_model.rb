# frozen_string_literal: true

# The board's own accounts before the accounts of the network: TTG Gate BBS imports them from this table.
class AccountModel < BBS::Model
  table :accounts
end
