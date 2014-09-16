# メトロパイパー

偉大なる秘密結社シェルショッカーに捧ぐ!

シェルスクリプトのパイプ駆使し、東京メトロのパイプ(=路線)の中身を覗いてしまえ!

## これは何だ?

最近開示された[東京メトロオープンデータ](https://developer.tokyometroapp.jp/)のWebAPIのデータから、今現在の列車の**接近情報**を表示するプログラムである。接近情報というのは、駅の電光掲示板にある

> 前々駅 -◆- 前駅 --- 当駅

というアレだ。しかし、今まではその駅のホームに行かないと見ることが出来なかったし、2つよりも前の駅の接近情報はわからなかった。

* あ、特急ロマンスカーが霞ヶ関駅に来てる。じゃあそろそろ表参道駅へ行くか。
* あー、南栗橋行間に合わなかった! えぇと次の東武線直通電車は今どのあたりに……? うーんもうしばらく後か、じゃあトイレに行っとくか。

という具合に、今いる駅から**もっと手前の駅の接近情報**や、あるいは駅にいなくても**これから行く予定の駅の接近情報**は知りたいもの。そんなアナタの願いを叶えるのがこのコマンドだ。


# つかいかた

## 0. 必要なもの

なぁに、大したものは要らん。UNIX環境と少々の追加コマンドがあれば動く。
レンタルサーバーなら大抵全部初めから揃っていることだろう。

| 必要なもの                           | 備考                                                          |
|:-------------------------------------|:--------------------------------------------------------------|
| POSIX準拠シェル(/bin/sh)とコマンド群 | FreeBSDやLinuxも勿論OK(BashやGNU拡張機能等は一切不要)         |
| curlコマンド                         | インストールしておく(主要Linuxディストリには大抵ある)         |

シェルスクリプトはPOSIX準拠で書いているつもりなので、curlコマンドさえどうにか用意することができればおそらくどこのUNIX環境でも動くはずだ。


## 1. 準備作業

シェルスクリプトで書いてあるからコンパイルなど一切不要。このプログラム一式をコピーして、最初にマスターデータを生成するシェルスクリプトを動かせば完了だ。

あ、[ユーザー登録](https://developer.tokyometroapp.jp/users/sign_up)をして、アクセストークンを貰ってくるのを忘れんようにな。それがないとこのアプリは動かせないぞ。

### 1) 開発者サイトにサインアップ

サインアップがまだならサインアップをすること。サイトは[ここ](https://developer.tokyometroapp.jp/users/sign_up)だ。なお、サインアップにはメールアドレスと、少々の時間(最長2日くらいらしいが、私は2時間くらいだった)が必要だ。

### 2) アクセストークンを発行する

アクセストークンとは、Twitterで言うところのApplication IDみたいなものだ。東京メトロのWebAPIにおいても、自作のWebアプリケーションを使いたければ発行しなければならない。残念ながらこれは公開してなならないので、このアプリ「メトロパイパー」を動かしたいなら各自取ってくること。

発行を受け付けている場所は[ここ](https://developer.tokyometroapp.jp/oauth/applications)だ。ただし、サインアップしたらデフォルトで1個生成されているので、それを使ってもよいのだが。

### 3) 「メトロパイパー」をダウンロード

[ZIPでダウンロード](https://github.com/ShellShoccar-jpn/metropiper/archive/master.zip)して展開してもよいが、gitコマンドが使えるなら下記のようにしてgit cloneするのが手っ取り早いぞ。

```sh:gitコマンド一発でメトロパイパー一式を取得
$ git clone https://github.com/ShellShoccar-jpn/metropiper.git
$ cd metropiper # ←メトロパイパーのホームディレクトリーに移動しておく
```

### 4) アクセストークンを設定

CONFというディレクトリーの中にある`ACCESSTOKEN.TXT`というファイルに、2)で取得してきたアクセストークンを書き込む。私が取得した時は**64桁の16進数**だったので、そうでなかったらそれはアクセストークンではないかもしれんぞ。

### 5) マスターファイルを作る準備

駅名や路線名など、最初に一回だけ入手しておけばよい情報を取得して、各種マスターファイルを作る作業を行う。

しかし一部はWebAPIではなくて、Web上に公開されているドキュメントページのHTMLをスクレイピングしなければならない。そこで、下記に指定するWebページのHTMLソースコードをどこかに保存しておくこと。

**[https://developer.tokyometroapp.jp/documents/odpt](https://developer.tokyometroapp.jp/documents/odpt)**

このページはログインしていないと表示されないので、Webブラウザーでログインしてからソースを表示し、コピペするというのが現実的ではないかと思う。そしてここでは説明の都合で、DATAディレクトリーの中に`metro_vocabulary.html`という名前で保存したものとする。

### 6) マスターファイルを生成

最後にコマンドを一発実行して、各種マスターファイルを生成する。インターネットに繋がっていれば5秒もかからずに生成できるだろう。下記のコマンドを実行せよ。

```sh:マスターファイルを生成する
$ SHELL/MK_METRO_MST.SH DATA/metro_vocabulary.html
```

## 2. 普段の使い方

### コマンド版

今現在のどこかの駅の接近情報が知りたいなーと思ったら、SHELLディレクトリーにある`VIEW_METROLOC.SH`コマンドを実行すればよい。ただしこのコマンドは引数を2つとる。

* 第1引数…知りたい駅の駅ナンバー
* 第2引数…行きたい駅の駅ナンバー(ただし同一路線であること)

東京メトロ各線の駅ナンバーは、[駅ナンバリング路線図](http://www.tokyometro.jp/station/common/pdf/rosen_j.pdf)参照。

### Web版

こりゃ便利なので、誰でも使えるようにとWebインターフェースを追加した。

というわけで、**[メトロパイパーWeb版](http://lab-sakura.richlab.org/METROPIPER/)**をWebブラウザーで開く。使い方は、説明しなくてもわかるでしょ?

### コマンドの例と、ありし日・時刻の実行結果

東陽町(T14)における中野方面(T01)接近情報

```sh:使用例(東陽町駅における中野方面の接近情報)
$ SHELL/VIEW_METROLOC.SH T14 T01
.. T23 西船橋   各停 中野行 (東京メトロ車両)
.. T23 西船橋   快速 三鷹行 (東京メトロ車両)
.. |
.. T22 原木中山
.. |            各停 中野行 (東京メトロ車両)
.. T21 妙典
.. |
.. T20 行徳     各停 中野行 (東京メトロ車両)
.. |
.. T19 南行徳
.. |
.. T18 浦安
.. |            各停 中野行 (東葉高速鉄道車両)
.. T17 葛西
.. |
.. T16 西葛西   各停 中野行 (東葉高速鉄道車両)
.. |            快速 中野行 (東京メトロ車両)
.. T15 南砂町
.. |
>> T14 東陽町
.. |
.. T13 木場     各停 三鷹行 (東京メトロ車両)
.. |
.. T12 門前仲町
.. |            各停 中野行 (東京メトロ車両)
.. T11 茅場町
.. |
.. T10 日本橋   各停 中野行 (東京メトロ車両)
.. |
.. T09 大手町
.. |
.. T08 竹橋
.. |
.. T07 九段下
.. |
.. T06 飯田橋   各停 三鷹行 (東京メトロ車両)
.. |
.. T05 神楽坂
.. |
.. T04 早稲田   各停 中野行 (東葉高速鉄道車両)
.. |
.. T03 高田馬場 快速 三鷹行 (JR東日本車両)
.. |
.. T02 落合     各停 中野行 (東京メトロ車両)
.. |
.. T01 中野
$ 
```

「やった、快速がもうすぐ来るじゃん」


# 補遺

ここで出てくるA1とかA2というのは出口ではない。(知ってた?)

## A1. ディレクトリー構成

このプログラムのディレクトリー構成を記す。

```text:ディレクトリー構成
     metropiper/
     ├─ SHELL/                ・シェルコマンドとして呼び出されるプログラムの置き場所
     │   ├─ MK_METRO_MST.SH    - マスターファイル生成スクリプト
     │   ├─ VIEW_METROLOC.SH   - 接近情報表示スクリプト(親)
     │   └─ VIEW_METROLOC_*.SH - 接近情報表示スクリプト(子)
     ├─ CONF/                 ・各種設定ファイル置き場
     │   └─ ACCESSTOKEN.TXT    - 取得したアクセストークンを設定するファイル
     ├─ DATA/                 ・各種マスターデータ等の置き場
     │   ├─ SNUM2RWSN_MST.TXT  - 駅ナンバーから各種情報を引くためのマスター
     │   ├─ RWC2RWN_MST.TXT    - 路線コードから路線名を引くためのマスター
     │   ├─ RWC2DIRC_MST.TXT   - 路線コードから路線の方面を引くためのマスター
     │   └─ METRO_VOC_MST.TXT  - その他各種コードから名称を引くためのマスター
     ├─ CGI/                  ・Webインターフェース用CGIプログラムの置き場所
     │   ├─ GET_SNUM_HTMLPART.AJAX.CGI
     │   │                      - 駅の一覧の<option>タグを生成する(Ajax)
     │   └─ GET_LOCINFO.AJAX.CGI
     │                           - VIEW_METROLOC.SHのWebインターフェース版(Ajax)
     ├─ TEMPLATE.HTML/        ・Webインターフェース用のテンプレートHTMLの置き場所
     │   └─ MAIN.HTML          - メインページのテンプレートHTML
     ├─ TOOL/                 ・シェルスクリプトアプリ開発を助けるコマンド群
     │                           ("Open usp Tukubai"という名で公開されているもの)
     │                           (ただしそれのシェルスクリプトによるクローン版)
     └─ UTL/                  ・その他、本システムで利用する汎用的なコマンド群
          └─ parsrj.sh          - シェルスクリプト製自作JSONパーサー
```

## A2. 既知の不具合

分岐のある路線(下記)は、分岐線の処理にうまく対応していないため、正しく表示されない。（ただし行先などを見ればわかるレベル）

* 千代田線(綾瀬から北綾瀬支線への分岐)
* 副都心線・有楽町線(小竹向原で西武有楽町線への分岐)
* 南北線(白金高輪から都営三田線への分岐)
* 丸ノ内線(中野坂上から方南町支線への分岐)

これらについては、個別のスクリプトを用意する予定である。

## A3. ライセンスとか

* 特に断りの無い限りパブリックドメインとする。
* ソースコード中に書かれている"Written by"表記は、質問先を示すものであり著作権を主張するものではない。
* 東京メトロのWebAPIが出力するデータ構造等、東京メトロの仕様に関しては東京メトロに権利があるので注意すること。
