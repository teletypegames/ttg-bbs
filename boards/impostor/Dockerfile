# syntax=docker/dockerfile:1
FROM ruby:3.3-alpine

RUN apk add --no-cache git openssh-client

WORKDIR /app

COPY bbs.rb ./
COPY Gemfile Gemfile.lock ./
COPY lib/ ./lib/
COPY screens/ ./screens/

RUN --mount=type=ssh \
    mkdir -p -m 0700 ~/.ssh && \
    ssh-keyscan -p 2222 git.teletype.hu >> ~/.ssh/known_hosts && \
    bundle install && \
    mkdir -p /app/data

EXPOSE 2323

CMD ["bundle", "exec", "ruby", "bbs.rb"]
