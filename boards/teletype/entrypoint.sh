#!/bin/sh
set -e
bundle update bbs
exec bundle exec ruby bbs.rb
