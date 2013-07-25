# 0.1.4 (July 25, 2013)

* Vagrantfileでinstance_idを指定せずにvagrant upした場合に、instance_id決定ロジックが can't convert nil into String を吐くケースがある問題を修正
* rsyncでのローカルファイル転送時に.gitディレクトリをexcludeするよう修正 

# 0.1.3 (July 24, 2013)

* access_key_id、secret_access_keyがVagrantfileで指定されていない場合に取得する環境変数名が間違っていた

# 0.1.0 (July 22, 2013)
* Initial release.
