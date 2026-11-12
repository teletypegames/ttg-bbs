# The image of TTG BBS: Ruby, the gems, ttg-common and the supervisor (bbs.rb). The boards'
# code is not in it: the stack's boards/ is mounted read-only on /app/boards, so a deploy that
# changes only a board leaves the image (and the container) as it is, and the supervisor
# restarts that board alone (Rubbs::MultiRunner, boards/.revision).
FROM ruby:3.4-alpine

RUN apk add --no-cache git build-base tzdata rsync

WORKDIR /app

ENV BUNDLE_WITHOUT=development \
    BBS_LOG_FORMAT=json \
    BBS_SHUTDOWN_SECONDS=20 \
    BBS_STATE_DIR=/app/state

COPY Gemfile Gemfile.lock ./
COPY boards/common/ttg-common.gemspec boards/common/
COPY boards/common/lib boards/common/lib
RUN bundle install

COPY bbs.rb boards.yml ./
COPY bin bin
RUN mkdir -p state && chown 1000:1000 state

USER 1000:1000

EXPOSE 2323-2335 2399

LABEL org.teletypegames.autoheal=true

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --start-interval=3s --retries=3 CMD ["bin/health"]

ENTRYPOINT ["bundle", "exec"]
CMD ["ruby", "bbs.rb"]
