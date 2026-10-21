FROM ruby:3.3-alpine

RUN apk add --no-cache git build-base

WORKDIR /app

ENV BUNDLE_WITHOUT=development

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY bbs.rb entrypoint.sh ./
COPY lib/ ./lib/
COPY bin/ ./bin/

RUN mkdir -p /app/data && chmod +x entrypoint.sh

EXPOSE 2323

ENTRYPOINT ["./entrypoint.sh"]
