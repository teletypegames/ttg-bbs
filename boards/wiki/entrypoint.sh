#!/bin/sh
set -e
# Start on the newest rubbs. If Gitea is unreachable (restart, 502), keep the installed version
# instead of exiting: a failed update must not keep the BBS down.
bundle update bbs || echo "rubbs update failed, starting with the installed version" >&2
exec bundle exec ruby wiki.rb
