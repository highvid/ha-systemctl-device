FROM ubuntu:noble-20240429 as build
RUN apt update -y && \
    apt install -y docker.io docker-compose
FROM ubuntu:noble-20240429

RUN apt update -y && \
    apt install -y systemd systemd-container git curl \
                   libssl-dev libz-dev build-essential gcc \
                   libffi-dev libyaml-dev

RUN git clone https://github.com/rbenv/rbenv.git ~/.rbenv
ENV PATH=${PATH}:/root/.rbenv/shims:/root/.rbenv/bin
RUN git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build

WORKDIR /application
COPY . /application

COPY --from=build /usr/bin/docker /usr/bin/docker
COPY --from=build /usr/bin/docker-compose /usr/bin/docker-compose

RUN rbenv install
RUN bundler_version=$( (tail -1 | xargs) < Gemfile.lock) && gem install bundler:$bundler_version
RUN bundle install

CMD ["/application/bin/start"]
