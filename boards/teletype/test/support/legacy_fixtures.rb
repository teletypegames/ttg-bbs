# frozen_string_literal: true

require 'fileutils'
require_relative '../../lib/domain/model/password'

# The data/ files of the CSV versions, as production has them, with the
# damage a killed write leaves: a torn last row, a half quoted field.
# `ruby test/support/legacy_fixtures.rb DIR` writes them into DIR.
module LegacyFixtures
  PASSWORD = 'secret-pass'
  SALT     = '00112233445566778899aabbccddeeff'

  def self.write(dir)
    FileUtils.mkdir_p(File.join(dir, 'boards'))
    FILES.each { |name, text| File.write(File.join(dir, name), text) }
    File.write(File.join(dir, 'accounts.csv'), accounts)
    File.write(File.join(dir, 'boards/general.csv'), GENERAL)
    File.write(File.join(dir, 'boards/tech.csv'), "05-01 10:00,Kali,\"a post\nof two lines\"\n")
    FileUtils.mkdir_p(File.join(dir, 'archive'))
    File.write(File.join(dir, 'archive/old.csv'), "not,ours\n")
  end

  def self.accounts
    digest = Password.digest(PASSWORD, SALT)
    "key,name,salt,digest,created_at\ntasi,Tasi,#{SALT},#{digest},2026-05-01T10:00:00+02:00\n" \
      "kali,Kali,#{SALT},#{digest},2026-05-02T10:00:00+02:00\nbroken,Broken,zz,zz,\n"
  end

  GENERAL = <<~CSV
    04-28 20:52,Tasi,hello
    04-30 08:29,Tasi,"with, a comma"
    05-11 20:03,Anonymous,guest post
    05-12 18:24,Kali,"torn quote
  CSV

  FILES = {
    'last_callers.csv' => "2026-05-12T20:41:32+02:00,Tasi,aa\n2026-05-13T16:27:11+02:00,Kali,bb,61\n" \
                          "2026-05-14T10:00:00+02:00,Tasi,cc,120\n2026-05-14T10:05:00+02:00,Ta",
    'last_read.csv' => "tasi,general,2\nkali,general,1\n",
    'oneliners.csv' => "2026-05-12T20:41:32+02:00,Tasi,first line\n2026-05-13T20:41:32+02:00,Kali,\"second\n",
    'profiles.csv' => "session_id,timestamp,username,signature,location,homepage,notes,art\n" \
                      "user-tasi,2026-05-01T10:00:00Z,Tasi,-- t,Budapest,https://teletypegames.org,hi,\n",
    'trivia_scores.csv' => "2026-05-12T20:41:32+02:00,Tasi,700,8\n2026-05-13T20:41:32+02:00,Kali,900,9\n" \
                           "2026-05-14T20:41:32+02:00,Kali,x,1\n",
    'votes.csv' => "favourite,tasi,SERMO,2026-05-01T10:00:00+02:00\nfavourite,tasi,TTG Trivia,2026-05-02T10:00:00+02:00\n" \
                   "favourite,kali,SERMO,2026-05-02T11:00:00+02:00\n",
    'mail.csv' => "id,timestamp,from,to,subject,body,read\n" \
                  "a1,2026-05-01T10:00:00+02:00,Kali,Tasi,Hi,\"two\nlines\",1\n" \
                  "a2,2026-05-02T10:00:00+02:00,Guest,Sysop,Feedback,nice board,0\n"
  }.freeze
end

LegacyFixtures.write(ARGV.fetch(0)) if $PROGRAM_NAME == __FILE__
