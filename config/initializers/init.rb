#とりあえずここにグローバル定数定義(config/initializersフォルダ内に配置しておくとアプリケーションの起動の際に実行される)

#グローバル定数の宣言
G_MAX_HEROKU_DB    = 10000 #HEROKUは10000行まで
G_MAX_USER_KINTAIS = 365   #ユーザー1人あたりがDBに記録できる勤怠レコードの総数。これ以降はそのユーザーの一番日が古いレコードから削除されていく。
G_MAX_USERS        = (G_MAX_HEROKU_DB / (G_MAX_USER_KINTAIS + 1) ).to_i - 1 #登録できるユーザーの最大数。万が一の2重投稿に備え、1人分空きを作る
