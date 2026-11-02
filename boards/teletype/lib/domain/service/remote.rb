# frozen_string_literal: true

# What a service answers when a remote source (the site, Gitea, the FTP
# server) failed: the repository raised, the error is logged here
# (BBS.log under +tag+) and the caller gets +fallback+, an empty list or
# nothing, so a dead API never reaches a screen as an error.
module Remote
  def self.read(tag, fallback)
    yield
  rescue StandardError => e
    BBS.log(tag, e)
    fallback
  end
end
