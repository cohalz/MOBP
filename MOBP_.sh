#!/bin/sh
source ~/.zshrc
source ~/.zprofile
# echo `date '+%y/%m/%d %H:%M:%S'`
fullpath=$0
##このスクリプトのファイル名
filename=`basename $0`
##このスクリプトのあるディレクトリのパス
location=`echo $fullpath | sed "s/$filename//"`

#スクリプトのあるディレクトリに移動
cd `echo $location`
ruby reply.rb
# echo `date '+%y/%m/%d %H:%M:%S'`
cd
