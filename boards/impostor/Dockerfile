FROM ruby:3.3-alpine

WORKDIR /app

COPY bbs.rb ./
COPY bbs/ ./bbs/

RUN mkdir -p /app/data

EXPOSE 2323

CMD ["ruby", "bbs.rb"]
