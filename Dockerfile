FROM ruby:2.4.0-alpine

RUN apk update && apk upgrade
RUN apk add build-base
RUN apk add \
			curl-dev \
			curl \
			make \
			gcc
WORKDIR /app
COPY Gemfile .
RUN bundle install -j4  && bundle clean
COPY . /app
CMD ["ruby", "app.rb"]
