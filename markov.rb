# coding: utf-8

require 'nkf'
require 'mysql2'
require_relative 'config'

#ランダム性と速度をここで調整

class Markov
  def initialize(natto, fetch_tweets, client)
    @natto = natto
    @fetch_tweets = fetch_tweets
    @client = client
    @whitelist = ['名詞', '感動詞','記号']
    @blacklist = ['接尾', '代名詞', '形容動詞語幹','句点','読点','非自立']
    @first_limit = 'rand() < 0.01 limit 10'
    @random_limit = ' and rand() < 0.05 limit 60'
  end

  def normalize_tweet(tweet1)
    return "" if tweet1 == nil
    tweet = tweet1.dup.to_s # 数字だけのツイートでunpack('U*')がエラーを吐くので全てtoString
    tweet.force_encoding('utf-8')
    #return nil if NKF.guess(tweet) != NKF::UTF8
    tweet.gsub!(/\.?@[0-9A-Za-z_:]+/, '')  # リプライをすべて削除
    tweet.gsub!(/RT/, '')  # RT削除
    tweet.gsub!(/https?:[\w\/\.]+/, '')  # URLを削除
    tweet.gsub!(/#/, ' #') #ハッシュタグ化
    tweet.gsub!(/[「」【】『』）]/, '') #括弧削除
    tweet.gsub!(/"/, '') #インジェクションやばそう対策
    tweet.gsub!(/'/, '') #インジェクションやばそう対策
    tweet.gsub!(/’/, '') #インジェクションやばそう対策
    tweet.gsub!(/\\\\/, '\\') #インジェクションやばそう対策
    tweet.gsub!(/.*(\\)/, '') #括弧削除
    tweet.gsub!(/&gt;/, '>') #実体参照
    tweet.gsub!(/&lt;/, '<') #実体参照
    tweet.gsub!(/&amp;/, '&') #実体削除
    # tweet.gsub!(/#[0-9A-Za-z_]+/, '')  # ハッシュタグを削除
    tweet
  end

  def wakatu(tweet)
    tmp = []
    nomtwi = normalize_tweet(tweet)
    if nomtwi != nil
      @natto.parse(nomtwi) do |n|
        tmp.push(n.surface)
      end
    end
    tmp
  end

  def first_is_noun?(tweet)
    nomtwi = normalize_tweet(tweet)

    if nomtwi != nil
      @natto.parse(nomtwi) do |n|
        hinshi = n.feature.split(',')
        return @whitelist.include?(hinshi[0]) && !@blacklist.include?(hinshi[1])
      end
    end
  end

  def create_markov_table(tweet)
    # 形態素4つずつから成るテーブルを生成
    order = 4

    nomtwi = normalize_tweet(tweet)
    wakati_array = Array.new
    wakati_array += wakatu(nomtwi)

    i = 0
    loop do
      wakati = wakati_array[i..(i+order-1)]
      break if wakati[order - 1] == nil
      query = "insert into  #{MARKOV_TABLE} values ('#{wakati[0]}', '#{wakati[1]}', '#{wakati[2]}', '#{wakati[3]}')"
      query.gsub!(/\\\'/,"'")
      @client.query(query)
      i += 1
    end
    query = "insert into #{MASTER_TABLE} values ('#{nomtwi}')"
    query.gsub!(/\\\'/,"'")
    @client.query(query)
  end

  def gen_first(tweet)
    wakati = []
    nomtwi = normalize_tweet(tweet)

    if nomtwi != nil
      @natto.parse(nomtwi) do |n|
        hinshi = n.feature.split(',')
        wakati.push(n.surface) if @whitelist.include?(hinshi[0]) && !@blacklist.include?(hinshi[1])
      end
    end
    wakati.sample
  end

  def gen_words(word,count=5)
    if count == 0 or word == nil
      query = "select * from #{MARKOV_TABLE} where " + @first_limit
      return @client.query(query)
    else
      query = "select * from #{MARKOV_TABLE} where #{FIRST_COLUMN} = '#{word}' or
                                                 #{SECOND_COLUMN} = '#{word}'"
      results = @client.query(query)
      if results.count == 0
        return gen_words(word,count-1)
      else
        return results
      end
    end
  end

  def generate_sentence(tweet,count=0)
    if tweet == ''
      results = gen_words(gen_first(@fetch_tweets.sample))
    else
      results = gen_words(gen_first(tweet))
    end

    selected = results.to_a.select { |result|
      first_is_noun?(result[FIRST_COLUMN]+result[SECOND_COLUMN]+result[THIRD_COLUMN]+result[FOURTH_COLUMN])
    }.sample

    markov_tweet = selected[FIRST_COLUMN] + selected[SECOND_COLUMN] +
        selected[THIRD_COLUMN] + selected[FOURTH_COLUMN]

    # 以後、''で終わるものを拾うまで連鎖を続ける
    loop do
      query = "select * from #{MARKOV_TABLE} where
              #{FIRST_COLUMN} = '#{selected[FOURTH_COLUMN]}'" + @random_limit
      results = @client.query(query)
      break if results.count == 0 # 連鎖できなければ諦める
      selected = results.to_a.sample
      markov_tweet += selected[SECOND_COLUMN] + selected[THIRD_COLUMN] +
          selected[FOURTH_COLUMN]
      break if selected[FOURTH_COLUMN] == '' #  or
    end

    markov_tweet = normalize_tweet(markov_tweet)

    #文字数オーバーしたら数回再試行
    if count < 3 and markov_tweet.size > 50
      markov_tweet = generate_sentence(tweet,count+1)
    end

    markov_tweet.gsub!(/　/,'')
    markov_tweet
  end

end
