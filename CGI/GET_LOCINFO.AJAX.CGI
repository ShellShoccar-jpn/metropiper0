#! /bin/sh

######################################################################
#
# GET_LOCINFO.AJAX.CGI
# 接近情報を返す
# Written by Rich Mikan(richmikan@richlab.org) at 2014/09/17
#
# [入力]
#    HTTP POSTで次のCGI変数を与える
#      from_snum : 「知りたい駅」の駅ナンバー
#      to_snum   : 「行きたい駅」の駅ナンバー
# [出力]
#    接近情報テキストを返す
#
# [備考]
#    「知りたい駅」と「行きたい駅」は同じ路線でなければならない
#
######################################################################


######################################################################
# 初期設定
######################################################################

# --- エラー終了関数定義 ---------------------------------------------
errorcode_exit() {
  cat <<-__HTTP_HEADER
	Status: 500 Internal Server Error
	Content-Type: text/plain

	500 Internal Server Error
	($@)
__HTTP_HEADER
  exit 1
}
error400_exit() {
  cat <<-__HTTP_HEADER
	Status: 400 Bad request
	Content-Type: text/plain

	400 Bad Request
	($@)
__HTTP_HEADER
  exit 1
}
dyingmessage() {
  printf 'Content-Type: text/plain\n\n'
  echo "$@"
  exit
}

# --- このシステムのホームディレクトリー -----------------------------
Homedir="$(d=${0%/*}/; [ "_$d" = "_$0/" ] && d='./'; cd "$d.."; pwd)"

# --- その他初期ディレクトリー等定義 ---------------------------------
# 1)コマンドパスの追加
PATH="$Homedir/UTL:$Homedir/TOOL:$PATH"
# 2)一時ファイル格納先
Tmp=/tmp/${0##*/}.$$
# 3)終了時の一時ファイル削除設定
exit_trap() { rm -f $Tmp-*; }
trap "exit_trap" EXIT HUP INT QUIT PIPE ALRM TERM


######################################################################
# CGI変数取得
######################################################################

# --- CGI変数(POST)を取得 --------------------------------------------
dd bs=${CONTENT_LENGTH:-0} count=1 2>/dev/null |
cgi-name                                       > $Tmp-cgivars

# --- 正当性確認 -----------------------------------------------------
s=$(nameread from_snum $Tmp-cgivars)
echo "_$s" | grep -q '^_[A-Za-z][0-9][0-9]$'
[ $? -eq 0 ] || { error400_exit 'Invalid station number on from_snum'; }
from_snum=$s
s=$(nameread to_snum $Tmp-cgivars)
echo "_$s" | grep -q '^_[A-Za-z][0-9][0-9]$'
[ $? -eq 0 ] || { error400_exit 'Invalid station number on to_snum'; }
to_snum=$s


######################################################################
# スクリプト実行
######################################################################

# --- HTTPレスポンスを出力 -------------------------------------------
cat <<-HTTP_RES
	Content-Type: text/plain; charset=UTF-8
	
	$($Homedir/SHELL/VIEW_METROLOC.SH $from_snum $to_snum 2>&1 | awk '/^[A-Za-z]/{sub(/^[A-Za-z0-9_.-]*: /,"",$0)} {print;}' | sed 's/^\.\./  /')
HTTP_RES


######################################################################
# 正常終了
######################################################################

exit 0
