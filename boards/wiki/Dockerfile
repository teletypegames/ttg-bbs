FROM ruby:3.3-alpine

RUN apk add --no-cache git build-base

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY wiki.rb entrypoint.sh ./
COPY lib/ ./lib/

RUN chmod +x entrypoint.sh

EXPOSE 2323

ENTRYPOINT ["./entrypoint.sh"]
