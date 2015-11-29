# coding: utf-8
Encoding.default_external = "UTF-8"
require 'twitter'
require 'natto'
require_relative 'markov'
require_relative 'config'

client = Mysql2::Client.new(:host => 'localhost', :database => DB_NAME , :username => 'root', :password => DB_PASSWD)
natto = Natto::MeCab.new
rest = Twitter::REST::Client.new do |config|
  config.consumer_key = YOUR_CONSUMER_KEY
  config.consumer_secret = YOUR_CONSUMER_SECRET
  config.access_token = YOUR_OAUTH_TOKEN
  config.access_token_secret = YOUR_OAUTH_TOKEN_SECRET
end
fetch_tweets = rest.home_timeline.map {|object|
  object.text
}
markov = Markov.new(natto,fetch_tweets,client)

str = markov.generate_sentence(ARGV[0])
if ARGV[0] == 'production'
  rest.update(str)
end
puts str
