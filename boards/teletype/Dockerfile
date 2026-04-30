FROM ruby:3.3-alpine

RUN apk add --no-cache git build-base

WORKDIR /app

COPY Gemfile ./
RUN bundle install

COPY bbs.rb ./
COPY lib/ ./lib/

RUN mkdir -p /app/data

EXPOSE 2323

CMD ["bundle", "exec", "ruby", "bbs.rb"]
