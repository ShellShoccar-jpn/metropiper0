#! /bin/sh

######################################################################
#
# MK_METRO_MST.SH
# 東京メトロオープンデータWebAPIから、主要マスターファイルを生成する
# Written by Rich Mikan(richmikan@richlab.org) at 2014/09/16
#
# [入力]
# ・下記のファイルを用意しておく
#    1. CONF/ACCESSTOKEN.TXT
#       コンテストで与えられたアクセストークンを記述したテキスト
# ・引数で下記を指定
#   [$1] : https://developer.tokyometroapp.jp/documents/odpt のHTML
#          ・(注)上記ページはログインしていないと取得できない
# [出力]
# ・下記のマスターファイルを作る
#    1. DATA/RWC2DIRC_MST.TXT
#       ・路線コードから方面コードを引くためのマスターファイル
#       ・1:路線コード(sorted) 2:方面コード
#    2. DATA/RWC2RWN_MST.TXT
#       ・路線コードから路線名を引くためのマスターファイル
#    3. DATA/SNUM2RWSN_MST.TXT
#       ・駅ナンバーから路線名や駅名等を引くマスターファイル
#       ・1:駅ナンバー(sorted) 2:路線コード 3:路線名 4:路線駅コード
#         5:駅名 6:方面コード(方面駅でない場合は"-")
#    4. DATA/METRO_VOC_MST.TXT
#       ・その他のボキャブラリーマスターファイル
#       ・1:各種コード(sorted) 2:各種名称
#    ※ 引数が正しく指定されなかった場合、4は生成しない。
#
# [備考]
# ・このスクリプトは、メトロ全線の運行時間帯に実行しなければならない
# ・要curlコマンド
#
######################################################################


######################################################################
# 初期設定
######################################################################

# --- 使用法表示関数定義 ---------------------------------------------
print_usage_and_exit() {
  local s
  s=$(awk 'BEGIN{printf("%070d",0)}' | tr 0 '#')
  awk "f==1&&/^${s}\$/{print;exit} f==0&&/^${s}\$/{f=1} f==1{print;}" "$0" 1>&2
  exit 1
}

# --- このシステムのホームディレクトリー -----------------------------
Homedir="$(d=${0%/*}/; [ "_$d" = "_$0/" ] && d='./'; cd "$d.."; pwd)"

# --- 与えられたアクセストークンを設定 -------------------------------
File_token=$Homedir/CONF/ACCESSTOKEN.TXT
if [ ! -f "$File_token" ]; then
  echo "${0##*/}: The file contains access token is not found." 1>&2
  exit 1
fi
appid=$(env - awk '/^[[:alnum:]]+$/' "$File_token")
if [ -z "$appid" ]; then
  echo "${0##*/}: The access token is not valid." 1>&2
  exit 1
fi

# --- その他初期ディレクトリー等定義 ---------------------------------
# 1)コマンドパスの追加
PATH="$Homedir/UTL:$Homedir/TOOL:$PATH"
# 2)一時ファイル格納先
Tmp=/tmp/${0##*/}.$$
# 3)終了時の一時ファイル削除設定
exit_trap() { rm -f $Tmp-*; }
trap "exit_trap" EXIT HUP INT QUIT PIPE ALRM TERM
# 4)その他
LF=$(printf '\\\n_');LF=${LF%_}  # sed内での改行を変数として扱うためのもの


######################################################################
# 引数確認・取得
######################################################################

# --- デフォルトのボキャブラリーHTMLファイル名(なし)設定 -------------
file_volhtml=''

# --- 引数が0または1であることの確認 ---------------------------------
[ $# -le 1 ] || print_usage_and_exit

# --- 引数1が正当なファイルであることの確認 --------------------------
[ \( -z "${1:-}" \) -o \( -f "${1:-}" \) ] || print_usage_and_exit

# --- ボキャブラリーHTMLファイルの設定 -------------------------------
file_volhtml=$1


######################################################################
# マスターファイルを生成するディレクトリーの作成
######################################################################

mkdir -p "$Homedir/DATA"
if [ $? -ne 0 ]; then
  echo "${0##*/}: Cannot make the director for master files." 1>&2
  exit 1
fi


######################################################################
# 方面コードマスター作成
# (このマスターは、メトロ全線の運行時間帯に実行しなければならない)
######################################################################

# --- 呼び出しURLの設定 ----------------------------------------------
url='https://api.tokyometroapp.jp/api/v2/datapoints?rdf:type=odpt:Train&acl:consumerKey='$appid

# --- 呼び出してマスターファイルを作る -------------------------------
curl -s $url                                      |
parsrj.sh                                         |
grep -E '\.odpt:railway |\.odpt:railDirection '   |
sed 's/^\$\[\([0-9]\{1,\}\)\]\.[^:]\{1,\}:/\1 /'  |
sort -k1n,1 -k2,2                                 |
awk '{print $3}'                                  |
awk 'NR%2!=0{printf("%s ",$0)} NR%2==0{print $0}' |
awk '{print $2,$1}'                               |
sort                                              |
uniq                                              > $Homedir/DATA/RWC2DIRC_MST.TXT
# 1:路線コード 2:方面コード                       #


######################################################################
# 路線名マスター作成
######################################################################

# --- 呼び出しURL(路線名マスター作成用)の設定 ------------------------
url='https://api.tokyometroapp.jp/api/v2/datapoints?rdf:type=odpt:Railway&acl:consumerKey='$appid

# --- 呼び出して路線名マスターファイルを作る -------------------------
curl -s $url                                      |
parsrj.sh                                         |
grep -E '\.owl:sameAs |\.dc:title '               |
sed 's/^\$\[\([0-9]\{1,\}\)\]\.[^:]\{1,\}:/\1 /'  |
sort -k1n,1 -k2,2                                 |
awk '{print $3}'                                  |
awk 'NR%2!=0{printf("%s ",$0)} NR%2==0{print $0}' |
sort -k1,1                                        > $Homedir/DATA/RWC2RWN_MST.TXT
# 1:路線コード 2:路線名
#


######################################################################
# 駅＆路線情報マスター作成
# (このマスターは、方面コードマスターに依存しているため、
#  メトロ全線の運行時間帯に実行しなければならない)
######################################################################

# --- 呼び出しURLの設定 ----------------------------------------------
url='https://api.tokyometroapp.jp/api/v2/datapoints?rdf:type=odpt:Station&acl:consumerKey='$appid

# --- 呼び出してマスターファイル(路線名コード状態)を作る -------------
curl -s $url                                                            |
parsrj.sh                                                               |
grep -E '\.owl:sameAs |\.odpt:stationCode |\.dc:title |\.odpt:railway ' |
sed 's/^\$\[\([0-9]\{1,\}\)\]\.[^:]\{1,\}:/\1 /'                        |
sort -k1n,1 -k2,2                                                       |
awk '{print $3}'                                                        |
awk 'NR%4!=0{printf("%s ",$0)} NR%4==0{print $0}'                       |
awk '{print $3,$1,$2,$4}'                                               |
sort -k2,2                                                              > $Tmp-stnum2codes
# 1:駅ナンバ 2:路線コード 3:路線駅コード 4:駅名

# --- 方面マスターから支線(丸ノ内線)の区別をなくしたマスターを作る ---
cat $Homedir/DATA/RWC2DIRC_MST.TXT   |
awk '{rwc=$1;                        #
      sc =$2; sub(/^.*\./  ,"", sc); #
      print rwc sc, $2}'             |
sort -k1,1                           > $Tmp-rwc-sc2dirc
# 1:路線コード(支線無し)+駅コード(方面駅検出に利用する) 2:方面コード

# --- 方面マスターと路線名マスターをJOINして目的のマスターファイルを作る
join -1 1 -2 2 -o 2.1,2.2,1.2,2.3,2.4 $Homedir/DATA/RWC2RWN_MST.TXT $Tmp-stnum2codes |
# 1:駅ナンバ 2:路線コード 3:路線名 4:路線駅コード 5:駅名                             #
awk '{rwc=$2; sub(/Branch$/,"", rwc);                                                #
      sc =$4; sub(/^.*\./  ,"", sc );                                                #
      print $1,$2,$3,$4,$5,rwc sc}'                                                  |
# 1:駅ナンバ 2:路線コード 3:路線名 4:路線駅コード 5:駅名                             #
# 6:路線コード(支線無し)+駅コード(方面駅検出に利用する)                              #
sort -k6,6                                                                           |
join -1 1 -2 6 -a 2 -o 2.1,2.2,2.3,2.4,2.5,2.6,1.2 $Tmp-rwc-sc2dirc -                |
sed 's/ $/ -/'                                                                       |
awk '{print $1,$2,$3,$4,$5,$7}'                                                      |
sort -k1,1                                                                           |
awk '/^F/{if(fnum == 0     ){fnum=substr($1,2,2)*1;                     }            # # (例外)副都心線のF01-F05は
          if(match($0,/-$/)){fstr=substr($0,5);sub(/\.[^.]+$/,".",fstr);}}           # # 有楽町線と共通で、
     /^Y/{n=substr($1,2,2); sncsub=$4;sub(/^.+\./,"",sncsub);                        # # APIからは出力されないので
          if(n*1<fnum){print "F" n,fstr sncsub,$5,$6;}                   }           # # Y01-Y05の情報に基づいて
     {print;                                                             }'          | # F01-F05をコピー生成する。
sort -k1,1                                                                           > $Homedir/DATA/SNUM2RWSN_MST.TXT
# 1:駅ナンバ 2:路線コード 3:路線名 4:路線駅コード 5:駅名 6:方面コード(方面駅でない場合は"-")


######################################################################
# ボキャブラリーマスター作成
######################################################################

# --- ボキャブラリー紹介ページをスクレイピングする -------------------
if [ -f "$file_volhtml" ]; then
  # 1)Webページからスクレイピング
  cat "$file_volhtml"            |
  tr -d '\n'                     |
  sed 's/<tr[^>]*>/'"$LF"'&/g'   |
  sed 's/<\/tr[^>]*>/&'"$LF"'/g' |
  grep '^<tr'                    |
  grep -v '<th[^>]*>'            |
  sed 's/<[^>]\{1,\}>/ /g'       |
  awk '{print $1,$2}'            > $Tmp-vocmaster0
  # 2)東京メトロの駅名は載っていないので駅＆路線情報マスターから抽出し、追記
  cat $Homedir/DATA/SNUM2RWSN_MST.TXT |
  awk '{print $4,$5}'                 >> $Tmp-vocmaster0
  # 3)ソートし、重複をとって完成
  cat $Tmp-vocmaster0 |
  sort                |
  uniq                > $Homedir/DATA/METRO_VOC_MST.TXT
  # 1:各種コード(sorted) 2:各種名称
fi


######################################################################
# 正常終了
######################################################################

exit 0