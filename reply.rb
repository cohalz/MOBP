# coding: utf-8

require 'twitter'
require 'tweetstream'
require 'natto'
require 'date'
require_relative 'markov'
require_relative 'config'

class ReplyDaemon
  def initialize
    puts 'Start initialization of daemon...'

    @rest = Twitter::REST::Client.new do |config|
      config.consumer_key = YOUR_CONSUMER_KEY
      config.consumer_secret = YOUR_CONSUMER_SECRET
      config.access_token = YOUR_OAUTH_TOKEN
      config.access_token_secret = YOUR_OAUTH_TOKEN_SECRET
    end
    TweetStream.configure do |config|
      config.consumer_key = YOUR_CONSUMER_KEY
      config.consumer_secret = YOUR_CONSUMER_SECRET
      config.oauth_token = YOUR_OAUTH_TOKEN
      config.oauth_token_secret = YOUR_OAUTH_TOKEN_SECRET
    end
    @stream = TweetStream::Client.new

    @pid_file_path = './reply_daemon.pid'
    @error_log_path = './reply_error.log'

    client = Mysql2::Client.new(:host => 'localhost', :database => DB_NAME, :username => 'root', :password => DB_PASSWD)
    natto = Natto::MeCab.new


    begin
      puts 'Fetching tweets...'
      fetch_tweets = @rest.home_timeline.map {|object|
        object.text
      }

      @markov = Markov.new(natto,fetch_tweets,client)

      puts 'Generating Tweet...'
      twi = @markov.generate_sentence('')
      `cat ./reply_daemon.pid | xargs kill`
      if ARGV[0] == '-notweet'
        puts(twi)
      else
        @rest.update(twi)
      end
      puts 'Finish initialization.'

    rescue => ex
      open(@error_log_path, 'a') { |f| 
        f.puts(Date.today.to_time)
        f.puts(ex.backtrace) 
        f.puts(ex.message) 
        f.puts('') } if @error_log_path
    end
  end

  def run
    daemonize
    begin
      @stream.userstream do |object|
        if object.is_a?(Twitter::Tweet)
          if object.text.include?('@' + BOT_SCREEN_NAME) && !(object.text.include?('RT'))
              reply = '@' + object.user.screen_name + ' ' + @markov.generate_sentence(object.text)
              @rest.update(reply[0, 140], { 'in_reply_to_status_id' => object.id })
          end
          if object.user.screen_name != BOT_SCREEN_NAME && !(object.text.include?('RT'))
            @markov.create_markov_table(object.text)
          end
        end
      end
    rescue => ex
      open(@error_log_path, 'a') { |f| 
        f.puts(Date.today.to_time)
        f.puts(ex.backtrace) 
        f.puts(ex.message) 
        f.puts('') } if @error_log_path
    end
  end

  def daemonize
    exit!(0) if Process.fork
    Process.setsid
    exit!(0) if Process.fork
    open_pid_file
  end

  def open_pid_file
    open(@pid_file_path, 'w') {|f| f << Process.pid } if @pid_file_path
  end
end

ReplyDaemon.new.run

