FROM ruby:3.3-alpine

RUN apk add --no-cache git build-base tzdata

WORKDIR /app

ENV BUNDLE_WITHOUT=development

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .
RUN mkdir -p data && chown 1000:1000 data

USER 1000:1000

EXPOSE 2323

ENTRYPOINT ["bundle", "exec"]
CMD ["ruby", "bbs.rb"]
