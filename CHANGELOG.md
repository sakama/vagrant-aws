### 0.2.1 (Aug 6, 2013)

* vagrant up後のサーバステータス取得ロジックが不適切で、既に複数サーバが存在する場合、rsyncによる同期が不適切なタイミングで始まってしまう問題を修正

## 0.2.0 (July 30, 2013)

* エンドポイント切り替え、リージョン・ゾーンの設定を正式サポート

### 0.1.6 (July 29, 2013)

* vagrant up直後にCtrl+Cで中断した場合に、vagrant statusでステータスが取得できない問題を修正

### 0.1.5 (July 27, 2013)

* gemspecファイルのライセンス表示を追加

### 0.1.4 (July 25, 2013)

* Vagrantfileでinstance_idを指定せずにvagrant upした場合に、instance_id決定ロジックが can't convert nil into String を吐くケースがある問題を修正
* rsyncでのローカルファイル転送時に.gitディレクトリをexcludeするよう修正 

### 0.1.3 (July 24, 2013)

* access_key_id、secret_access_keyがVagrantfileで指定されていない場合に取得する環境変数名が間違っていた

## 0.1.0 (July 22, 2013)
* Initial release.
