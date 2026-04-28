FROM ruby:3.3-alpine

RUN apk add --no-cache git

WORKDIR /app

COPY bbs.rb ./
COPY Gemfile Gemfile.lock ./
COPY lib/ ./lib/
COPY screens/ ./screens/

RUN bundle install && mkdir -p /app/data

EXPOSE 2323

CMD ["bundle", "exec", "ruby", "bbs.rb"]
