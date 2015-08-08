# coding: utf-8
Encoding.default_external = "UTF-8"
require 'twitter'
require 'csv'
require_relative 'markov'
require_relative 'config'

tweets_table = Array.new
CSV.foreach(CSV_PATH, :headers => true) do |row|
  tweet = normalize_tweet(row['text'])
  next if !tweet
  tweets_table << tweet
end

markov_table = create_markov_table(tweets_table)

str = generate_tweet(markov_table, ARGV[0])
if ARGV[0] == 'production'
  rest = Twitter::REST::Client.new do |config|
    config.consumer_key = YOUR_CONSUMER_KEY
    config.consumer_secret = YOUR_CONSUMER_SECRET
    config.access_token = YOUR_OAUTH_TOKEN
    config.access_token_secret = YOUR_OAUTH_TOKEN_SECRET
  end
  rest.update(str)
end
puts "[tweet] #{str}"
