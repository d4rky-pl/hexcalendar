FROM ruby:2.7-alpine

COPY . /app
WORKDIR /app

RUN apk update && apk upgrade && apk add --update alpine-sdk && apk add --no-cache make cmake 

RUN bundle install
RUN apk del alpine-sdk make cmake

EXPOSE 8080
ENTRYPOINT bundle exec puma -C config/puma.rb
