# coding: utf-8
Encoding.default_external = "UTF-8"
require 'twitter'
require 'csv'
require_relative 'markov'
require_relative 'config'

client = Mysql2::Client.new(:host => 'localhost', :database => DB_NAME , :username => 'root', :password => DB_PASSWD)
str = generate_tweet(client,0,[],ARGV[0])
if ARGV[0] == 'production'
  rest = Twitter::REST::Client.new do |config|
    config.consumer_key = YOUR_CONSUMER_KEY
    config.consumer_secret = YOUR_CONSUMER_SECRET
    config.access_token = YOUR_OAUTH_TOKEN
    config.access_token_secret = YOUR_OAUTH_TOKEN_SECRET
  end
  rest.update(str)
end
puts str
