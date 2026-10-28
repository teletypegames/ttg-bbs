#!/bin/sh
set -e
# Start on the newest rubbs. After a server restart every container comes up together and Gitea
# answers 502 for a while, so wait up to a minute for it first. If it is still unreachable, keep
# the installed version instead of exiting: a failed update must not keep the blog down.
RUBBS_GIT=https://git.teletypegames.org/engines/rubbs.git
tries=0
until git ls-remote "$RUBBS_GIT" HEAD >/dev/null 2>&1 || [ "$tries" -ge 12 ]; do
  tries=$((tries + 1))
  sleep 5
done
bundle update bbs || echo "rubbs update failed, starting with the installed version" >&2
exec bundle exec ruby bbs.rb
