FROM ruby:3.3.1

RUN apt update -y && \
    apt intall systemctl

WORKDIR /application
COPY . /application

RUN bundler_version=$( (tail -1 | xargs) < Gemfile.lock) && gem install bundler:$bundler_version
RUN bundle install

CMD ["/application/bin/start"]
