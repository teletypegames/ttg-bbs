# frozen_string_literal: true

# How one RFC is related to another (a row of the relations table of
# data/index.sqlite3): RFC +rfc+ +kind+ RFC +target+, as the index says
# (both ways: RFC 793 is obsoleted by 9293, 9293 obsoletes 793).
class RelationModel < BBS::Model
  table :relations, database: :index

  # The kinds of relations, and what each reads as, in the order shown.
  RELATIONS = {
    'obsoleted_by' => 'obsoleted by',
    'obsoletes'    => 'obsoletes',
    'updated_by'   => 'updated by',
    'updates'      => 'updates',
    'see_also'     => 'see also'
  }.freeze
  ROW = %i[rfc kind target].freeze

  # The RFCs related to +number+ as [relation, RfcModel], in the order of
  # RELATIONS, each kind by number.
  def self.of(number)
    rows = RfcModel.guard([]) { targets(Integer(number)).all }
    rows.map { |rfc| [rfc.values.delete(:kind), rfc] }
      .sort_by { |kind, rfc| [RELATIONS.keys.index(kind), rfc.number] }
      .map { |kind, rfc| [RELATIONS.fetch(kind), rfc] }
  end

  # Writes +rows+ (values in the order of ROW).
  def self.insert_rows(rows) = dataset.import(ROW, rows)

  # The RFCs +number+ is related to, each with the kind.
  def self.targets(number)
    RfcModel.select(*RfcModel::COLUMNS.map { |c| Sequel[:rfcs][c] }).select_append(Sequel[:relations][:kind])
      .join(:relations, target: :number).where(Sequel[:relations][:rfc] => number)
      .order(Sequel[:relations][:kind], Sequel[:rfcs][:number])
  end

  private_class_method :targets
end
