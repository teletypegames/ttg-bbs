FROM ruby:3.3-alpine

WORKDIR /app

COPY bbs.rb ./
COPY Gemfile Gemfile.lock ./
COPY lib/ ./lib/
COPY gems/ ./gems/
COPY screens/ ./screens/

RUN bundle install && mkdir -p /app/data

EXPOSE 2323

CMD ["bundle", "exec", "ruby", "bbs.rb"]
