# frozen_string_literal: true

# An editor of the blog: one who may log in and write.
UserModel = Data.define(:id, :name) do
  def self.from_row(row) = new(id: row['id'], name: row['name'])
end
