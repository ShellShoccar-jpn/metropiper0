#! /bin/sh

######################################################################
#
# VIEW_METROLOC.SH
# 列車接近情報を表示
# Written by Rich Mikan(richmikan@richlab.org) at 2014/09/16
#
# [入力]
# ・引数で下記を指定
#     $1 : 今見たい駅の駅ナンバー
#     $2 : 行先を指示するための駅ナンバー(同じ路線であること)
# ・下記のファイルを用意しておく
#    1. CONF/ACCESSTOKEN.TXT
#       コンテストで与えられたアクセストークンを記述したテキスト
#    2. DATA/SNUM2RWSN_MST.TXT
#       駅ナンバーから路線名や駅名等を引くマスターファイル
#    3. DATA/METRO_VOC_MST.TXT
#       その他(種別・行先名・車両所有業者名等)のボキャブラリーマスターファイル
#    ※ 2,3のファイルはMK_METRO_MST.SHを実行すると得られる。
# [出力]
# ・列車接近情報を標準出力に出す
# ・フォーマットは次のとおり
#   1:自位置インデックス 2:駅ナンバー(駅間の場合は"|")+駅名(駅間の場合は"-")
#   3:列車情報(種別名+目的駅名+車両所有業者名)
#
# [備考]
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

# --- 必要なマスターファイルの存在確認 -------------------------------
# 1)駅ナンバーマスター
if [ ! -f "$Homedir/DATA/SNUM2RWSN_MST.TXT" ]; then
  echo "${0##*/}: The master file (SNUM2RWSN_MST.TXT) is not found." 1>&2
  exit 1
fi
# 2)各種ボキャブラリーマスター
if [ ! -f "$Homedir/DATA/METRO_VOC_MST.TXT" ]; then
  echo "${0##*/}: The master file (SNUM2RWSN_MST.TXT) is not found." 1>&2
  exit 1
fi

# --- 与えられたアクセストークンを設定 -------------------------------
File_token=$Homedir/CONF/ACCESSTOKEN.TXT
if [ ! -f "$File_token" ]; then
  echo "${0##*/}: The file contains access token is not found." 1>&2
  exit 1
fi
appid=$(env - awk '/^[[:alnum:]]+$/' "$File_token")
if [ -z "$appid" ]; then
  echo "${0##*/}: The access token is not invalid." 1>&2
  exit 1
fi

# --- その他定義 -----------------------------------------------------
# 1)コマンドパスの追加
PATH="$Homedir/UTL:$Homedir/TOOL:$PATH"
# 2)一時ファイル格納先
Tmp=/tmp/${0##*/}.$$
# 3)終了時の一時ファイル削除設定
exit_trap() { rm -f $Tmp-*; }
trap "exit_trap" EXIT HUP INT QUIT PIPE ALRM TERM


######################################################################
# 引数確認・取得
######################################################################

# --- 書式の正当性確認 -----------------------------------------------
[ $# -eq 2 ] || print_usage_and_exit
echo "_$1" | grep -iq '^_[A-Z][0-9][0-9]$' || print_usage_and_exit
echo "_$2" | grep -iq '^_[A-Z][0-9][0-9]$' || print_usage_and_exit

# --- 駅ナンバーの存在確認 -------------------------------------------
printf '%s\n%s\n' $1 $2                          |
sort                                             |
join -1 1 -2 1 $Homedir/DATA/SNUM2RWSN_MST.TXT - |
awk '{print} END{exit (NR==2)?0:1}'              > $Tmp-2stns
if [ $? -ne 0 ]; then
  echo "${0##*/}: 存在しない駅ナンバーが指定されています。"
  exit 1
fi

# --- 同一路線の駅ナンバーであることの確認 ---------------------------
cat $Tmp-2stns              |
sed 's/^\(.\).*/\1/'        |
tr a-z A-Z                  |
uniq                        |
awk 'END{exit (NR==1)?0:1}'
if [ $? -ne 0 ]; then
  echo "${0##*/}: 異なる路線の駅ナンバーは指定できません。"
  exit 1
fi

# --- 駅ナンバー変数をセット -----------------------------------------
from_snum=$1
to_snum=$2


######################################################################
# 個別スクリプトへの分岐
######################################################################

# --- 個別スクリプトを用いる必要があるかどうか判断する ---------------
from_rw=${from_snum%[0-9][0-9]}
to_rw=${to_snum%[0-9][0-9]}
if   [ $from_snum = 'C20'                                             ]; then
  # 千代田線北綾瀬支線専用スクリプト
  File_script="$Homedir/SHELL/VIEW_METROLOC_c.SH"
elif [ \( $from_snum = 'C19' \) -a \( $from_snum = 'C20' \)           ]; then
  # 千代田線北綾瀬支線専用スクリプト
  File_script="$Homedir/SHELL/VIEW_METROLOC_c.SH"
elif [ $from_rw = 'C'                                                 ]; then
  # 千代田線本線専用スクリプト
  File_script="$Homedir/SHELL/VIEW_METROLOC_C.SH"
elif [ \( $from_rw = 'F' \) -o \( $from_rw = 'Y' \)                   ]; then
  # 副都心線・有楽町線専用スクリプト
  File_script="$Homedir/SHELL/VIEW_METROLOC_FY.SH"
elif [ $from_rw = 'm'                                                 ]; then
  # 丸の内線方南町支線用スクリプト
  File_script="$Homedir/SHELL/VIEW_METROLOC_m.SH"
elif [ \( $to_rw = 'm' \) -a \( $((${from_snum#[A-Za-z]}*1)) -ge 6 \) ]; then
  # 丸の内線方南町支線用スクリプト
  File_script="$Homedir/SHELL/VIEW_METROLOC_m.SH"
elif [ $from_rw = 'M'                                                 ]; then
  # 丸の内線本線専用スクリプト
  File_script="$Homedir/SHELL/VIEW_METROLOC_M.SH"
elif [ $from_rw = 'N'                                                 ]; then
  # 南北線専用スクリプト
  File_script="$Homedir/SHELL/VIEW_METROLOC_N.SH"
fi

# --- 例外スクリプトが存在すればそちらへ分岐 -------------------------
if [ -x "$File_script" ]; then
  rm -f $Tmp-*
  exec  "$File_script" $from_snum $to_snum
fi

# --- そうでなければ標準スクリプトへ分岐 -----------------------------
File_script="$Homedir/SHELL/VIEW_METROLOC_0.SH"
if [ -x "$File_script" ]; then
  rm -f $Tmp-*
  exec  "$File_script" $from_snum $to_snum
fi


######################################################################
# ここへ来たらスクリプトが見つからなかったのでエラー
######################################################################

echo "${0##*/}: No child scripts found." 1>&2
exit 1
