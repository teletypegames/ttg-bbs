FROM ruby:3.3-alpine

RUN apk add --no-cache git build-base tzdata

WORKDIR /app

ENV BUNDLE_WITHOUT=development \
    BBS_LOG_FORMAT=json \
    BBS_SHUTDOWN_SECONDS=20

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .
RUN mkdir -p data && chown 1000:1000 data

USER 1000:1000

EXPOSE 2323

LABEL org.teletypegames.autoheal=true

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --start-interval=3s --retries=3 \
  CMD printf 'BBS-HEALTH\r\n' | nc -w 5 127.0.0.1 2323 | grep -q '^OK'

ENTRYPOINT ["bundle", "exec"]
CMD ["ruby", "bbs.rb"]
