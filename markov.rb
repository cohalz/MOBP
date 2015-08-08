# coding: utf-8

# require 'igo-ruby'
require 'natto'
require 'nkf'
require 'open-uri'
require 'json'

BEGIN_FLG = '[BEGIN]'
END_FLG = '[END]'

def normalize_tweet(tweet1)
  tweet = tweet1.dup.to_s # 数字だけのツイートでunpack('U*')がエラーを吐くので全てtoString
  return nil if NKF.guess(tweet) != NKF::UTF8
  tweet.gsub!(/\.?@[0-9A-Za-z_:]+/, '')  # リプライをすべて削除
  tweet.gsub!(/RT/, '')  # RT削除
  tweet.gsub!(/.*I'm\sat.*/, '')  # 4sq削除
  tweet.gsub!(/.*4sq.*/, '')  # 4sq削除
  tweet.gsub!(/https?:[\w\/\.]+/, '')  # URLを削除
  tweet.gsub!(/#/, ' #') #ハッシュタグ化
  tweet.gsub!(/[「」【】『』）]/, '') #括弧削除
  tweet.gsub!(/&gt;/, '>') #括弧削除
  tweet.gsub!(/&lt;/, '<') #括弧削除
  tweet.gsub!(/&amp;/, '&') #括弧削除
  tweet.gsub!(/#.*[Mm]atsuri/, '') #検索妨害になるため削除
  tweet.gsub!(/デイリーIT新聞紙/, '') #検索妨害になるため削除
  tweet.gsub!(/#kyon_kao_wedding/, '') #検索妨害になるため削除
  tweet.gsub!(/#[Mm]omonga[Vv]im/, '') #検索妨害になるため削除
  # tweet.gsub!(/#[0-9A-Za-z_]+/, '')  # ハッシュタグを削除
  tweet
end

def create_markov_table(tweets)
  natto = Natto::MeCab.new
  # tagger = Igo::Tagger.new('./ipadic')

  # 3階のマルコフ連鎖
  markov_table = Array.new
  markov_index = 0

  # 形態素3つずつから成るテーブルを生成
  tweets.each do |tweet|
    tmp = []
    nomtwi = normalize_tweet(tweet)
    if nomtwi != nil
      natto.parse(nomtwi) do |n|
        tmp.push(n.surface)
      end
    end
    wakati_array = Array.new
    wakati_array << BEGIN_FLG
    wakati_array += tmp
    wakati_array << END_FLG

    # 要素は最低6つあれば[BEGIN]で始まるものと[END]で終わるものの2つが作れる　
    next if wakati_array.size < 6
    i = 0
    loop do
      markov_table[markov_index] = wakati_array[i..(i+3)]
      markov_index += 1
      break if wakati_array[i+3] == END_FLG
      i += 1
    end
  end
  markov_table
end

def generate_first(markov_table)
  selected_array = Array.new
  markov_table.each do |markov_array|
    if markov_array[0] == BEGIN_FLG
      selected_array << markov_array
    end
  end
  selected_array.sample
end

def generate_first2(markov_table,tweet)
  wakati = []
  whitelist = ['名詞', '感動詞']
  blacklist = ['接尾', '代名詞', '形容動詞語幹']
  natto = Natto::MeCab.new  
  nomtwi = normalize_tweet(tweet)
  selected = []

  if nomtwi != nil
    natto.parse(nomtwi) do |n|
      hinshi = n.feature.split(',')
      wakati.push(n.surface) if whitelist.include?(hinshi[0]) && !blacklist.include?(hinshi[1])
    end
  end
    # 先頭（[BEGIN]から始まるもの）を選択
    selected_array = Array.new
    markov_table.each do |markov_array|
      wakati.each do |w|
        if markov_array[0] == w || markov_array[1] == w || markov_array[2] == w || markov_array[3] == w
          selected_array << markov_array 
        end
      end
    end
    selected = selected_array.sample
    if selected != nil
      selected
    else
      []
    end
end

def generate_tweet(markov_table,tweet='')
  # 先頭（[BEGIN]から始まるもの）を選択
  selected = Array.new
  markov_tweet = ''
  selected = generate_first2(markov_table,tweet) if tweet != ''
  selected = generate_first(markov_table) if selected.size == 0
  markov_tweet = selected[1] + selected[2] + selected[3] if selected.size != 0
  while true
    # 以後、[END]で終わるものを拾うまで連鎖を続ける
    loop do
      selected_array = Array.new
      markov_table.each do |markov_array|
        if markov_array[0] == selected[3]
          selected_array << markov_array
        end
      end
      break if selected_array.size == 0 # 連鎖できなければ諦める
      selected = selected_array.sample
      if selected[3] == END_FLG
        markov_tweet += selected[1] + selected[2]
        break
      else
        markov_tweet += selected[1] + selected[2] + selected[3]
      end
    end
    markov_tweet = normalize_tweet(markov_tweet)
    # If generated tweet size is greater than 100, tweet random Kaomoji
    if markov_tweet.size > 60
      markov_tweet = generate_tweet(markov_table,tweet)
      break
      # begin
      #   markov_tweet = get_kaomoji
      #   break
      # rescue
      #   next
      # end
    else
      break
    end
  end
  markov_tweet.gsub!(/\[END\]/, '')
  markov_tweet
end

def get_kaomoji
  open('http://kaomoji.n-at.me/random.json') do |f|
    JSON.load(f)['record']['text']
  end
end
