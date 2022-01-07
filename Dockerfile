FROM ruby:3.1.0-slim

# Install rugged dependencies
RUN apt-get update -qq \
    && apt-get install cmake zlib1g zlib1g-dev libssh2-1-dev -y \
    && rm -rf /var/lib/apt/lists/*

RUN gem install bundler -v 2.3.3

ENV GEM_HOME="/usr/local/bundle"
ENV PATH $GEM_HOME/bin:$GEM_HOME/gems/bin:$PATH

WORKDIR /plugin
# Files that will change bundle dependencies
ADD Gemfile* *.gemspec /plugin/
ADD lib/release_drafter/version.rb /plugin/lib/release_drafter/
# Fix used Gemfile for plugin execution
RUN bundle install
# Add the whole plugin
ADD . /plugin
# Install built gem locally
RUN bundle exec rake install
# By default execute plugin code
CMD 'release-drafter'
