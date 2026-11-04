# frozen_string_literal: true

# An RFC in a series (a row of the series table of data/index.sqlite3):
# +series+ STD, BCP or FYI, its +number+ there, and the +rfc+ that stands
# for it ("STD 7" is RFC 9293).
class SeriesModel < BBS::Model
  table :series, database: :index

  ROW = %i[series number rfc].freeze

  # The series RFC +number+ is part of: ["STD 7"].
  def self.of(number)
    RfcModel.guard([]) { where(rfc: Integer(number)).order(:series, :number).map { |s| "#{s.series} #{s.number}" } }
  end

  # The RFCs of a series (+kind+ STD, BCP or FYI) as [label, RfcModel]:
  # ["STD 7", RFC 9293], by series number.
  def self.rfcs(kind)
    rows = RfcModel.guard([]) do
      members.select_append(Sequel[:series][:number].as(:series_number)).where(Sequel[:series][:series] => kind)
             .order(Sequel[:series][:number], Sequel[:rfcs][:number]).all
    end
    rows.map { |rfc| ["#{kind} #{rfc.values.delete(:series_number)}", rfc] }
  end

  # The members of series +kind+ +number+ ("STD", 7).
  def self.members_of(kind, number)
    RfcModel.guard([]) do
      members.where(Sequel[:series][:series] => kind, Sequel[:series][:number] => Integer(number))
             .order(Sequel[:rfcs][:number]).all
    end
  end

  # Writes +rows+ (values in the order of ROW).
  def self.insert_rows(rows) = dataset.import(ROW, rows)

  # The RFCs joined to their rows of the series table.
  def self.members = RfcModel.select(*RfcModel::COLUMNS.map { |c| Sequel[:rfcs][c] }).join(:series, rfc: :number)

  private_class_method :members
end
