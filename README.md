# vagrant-niftycloud

[![Gem Version](https://badge.fury.io/rb/vagrant-niftycloud.png)](http://badge.fury.io/rb/vagrant-niftycloud)
[![Dependency Status](https://gemnasium.com/sakama/vagrant-niftycloud.png)](https://gemnasium.com/sakama/vagrant-niftycloud)
[![Build Status](https://travis-ci.org/sakama/vagrant-niftycloud.png)](https://travis-ci.org/sakama/vagrant-niftycloud)
[![Code Climate](https://codeclimate.com/github/sakama/vagrant-niftycloud.png)](https://codeclimate.com/github/sakama/vagrant-niftycloud)

[Vagrant](http://www.vagrantup.com) 1.2以降のバージョンのproviderとして[ニフティクラウド](http://cloud.nifty.com/) を使えるようにするためのプラグインです。

Vagrantでニフティクラウド上のサーバインスタンスの制御や、[Chef](http://www.opscode.com/chef/)や[Puppet](https://puppetlabs.com/) 等を使ったサーバのprovisioningが可能となります。

Chef以外の動作確認は行なっていませんが、プラグインで行なっているのはSSH実行可能な状態にすることとrsyncによるファイル転送だけなので、Vagrantでサポートされているものであれば動作するのではないかと思います。

**注意:** このプラグインはVagrant 1.2以降に対応しています。

## 機能

* ニフティクラウド上のサーバインスタンスの起動
* Vagrantから起動したインスタンスへのSSH
* Chef/Puppet等を使用したインスタンスのprovisioning
* `rsync`を使用したcookbook等の転送

## Quick Start

### プラグインのインストール

まずVagrant 1.2以降をインストールして下さい。

Vagrantは1.1からgem経由ではなく[パッケージでのインストール](http://downloads.vagrantup.com/)に変わっているので注意してください。

vagrant upを実行する前に、VirtualBox等でVagrantを使用する時と同じようにboxファイルをVagrantに追加する必要があります。

自分でboxファイルを作成するか、こちらで用意しているboxファイルを使用して、任意の名前でダミーのboxを追加して下さい。

```
$ vagrant plugin install vagrant-niftycloud
$ vagrant box add dummy https://github.com/sakama/vagrant-niftycloud/raw/master/dummy.box
```

### OSイメージの作成

Vagrant自体の仕様により、以下の制約があります。

* サーバに接続するvagrantユーザがパスワードなしでsudo実行できる必要がある (rootユーザではprovisioning実行に失敗します)
* sudoがttyなしで実行できる必要がある
* サーバに接続する際のSSH秘密鍵はパスフレーズが空で設定されている必要がある(rsyncでのファイル同期に失敗します)

以上の理由により、`ニフティクラウド公式のOSイメージでは動作しません`

上記条件をクリアしたサーバイメージをプライベートイメージ等で用意する必要があります。

OSイメージ作成の手順は以下のようになります。

chef-soloやchef-clientを予めインストールしておくかどうかはケースバイケースです。

vagrant up時に[vagrant-omnibus](https://github.com/schisamo/vagrant-omnibus)を使うという手もあります。

```
## rootで実行
# groupadd vagrant
# useradd vagrant -g vagrant -G wheel
# passwd vagrant

# su - vagrant
## vagrantユーザで実行
$ ssh-keygen -t rsa
$ cd .ssh
$ mv id_rsa.pub authorized_keys(id_rsaをローカルに保存する=接続する際のSSH秘密鍵となる)

## rootで実行
# visudo
Defaults requirettyをコメントアウト
## 最終行に以下を追加
vagrant        ALL=(ALL)       NOPASSWD: ALL

## chef-soloやchef-clientをインストールしておく場合
# curl -L https://www.opscode.com/chef/install.sh | sudo bash
```

作成したイメージのimage_idをVagrantfile内で指定する必要があります。

image_idについては[ニフティクラウドSDK for Ruby](http://cloud.nifty.com/api/sdk/#ruby)や[ニフティクラウド CLI](http://cloud.nifty.com/api/cli/) 等を使うと確認可能です。

### Vagrantfileの作成

Vagrantfileを以下のような内容で作成します。
サンプルのVagrantfile ([Chef用](https://github.com/sakama/vagrant-niftycloud/blob/master/Vagrantfile.chef.sample)) も参考にして下さい。

Vagrantfileの`config.vm.provider`ブロックで各種パラメータを指定して下さい。

```
Vagrant.configure("2") do |config|
  config.vm.box = "dummy"

  config.vm.provider :niftycloud do |niftycloud, override|
    niftycloud.access_key_id = ENV["NIFTY_CLOUD_ACCESS_KEY"] || "<Your Access Key ID>"
    niftycloud.secret_access_key = ENV["NIFTY_CLOUD_SECRET_KEY"] || "<Your Secret Access Key>"

    niftycloud.image_id = "26"
    niftycloud.key_name = "<YOUR SSH KEY NAME>"
    niftycloud.password = "<ROOT PASSWORD YOU WANT TO SET>"
    override.ssh.username = "vagrant"
    override.ssh.private_key_path = "PATH TO YOUR PRIVATE KEY"
  end
end
```

以上の手順で`vagrant up`コマンドのproviderオプションに`niftycloud`を指定できるようになります。

### コマンド

```

# サーバ立ち上げ、provisioningの実行
$ vagrant up --provider=niftycloud

# 立ち上げたサーバへのprovisioningの実行
$ vagrant provision

# サーバの一時停止
$ vagrant halt

# サーバの一時停止(haltと同じ)
$ vagrant suspend

# 停止中のサーバの起動
$ vagrant resume

# サーバの破棄
$ vagrant destroy

```


SSH接続やcookbook等を使ったサーバのprovisioningに失敗する場合、以下のような理由が考えられます。

* SSHオプションが正しくない
* SSHオプションに正しい秘密鍵が指定されていない
* SSH秘密鍵のパーミッションが正しくない
* vagrantユーザによるパスワード無しでのsudo実行が不可となっている
* sudoがttyなしで実行不可となっている
* ニフティクラウドのFirewallルールによりSSH接続が遮断されている

共通設定についてはboxファイル中に含めることもできます。

こちらで用意している"dummy"boxファイルにはデフォルトオプションは指定されていません。


## Box Format

自分でboxファイルを作成したい場合[examble_box](https://github.com/sakama/vagrant-niftycloud/tree/master/example_box)を参考にして下さい。

こちらのディレクトリにはboxの作成方法についてのドキュメントも置いてあります。

boxフォーマットは`metadata.json`と`Vagrantfile`をtar.gzで圧縮したものです。

VirtualBoxやVMWare Fusion向けの数GBあるboxと比較すると遙かに軽量で、デフォルト設定を記述する場所という位置付けとなっています。

`Vagrantfile` で指定された項目/値はproviderとしてniftycloudを指定した場合のデフォルト値として扱われるため、複数メンバーで作業する場合等はオリジナルのboxを作成しておくと便利です。


## 設定

以下の様なパラメータに対応しています。


* `access_key_id` - ニフティクラウドのAccessKey。[コントロールパネルから取得した値](http://cloud.nifty.com/help/status/api_key.htm)を指定。
* `secret_access_key` - ニフティクラウドAPI経由でアクセスするためのSecretAccessKey。[コントロールパネルから取得した値](http://cloud.nifty.com/help/status/api_key.htm)を指定して下さい。
* `instance_id` - サーバ名。指定がない場合ランダムなIDを付与。Vagrantfileを複数人で共有している場合、指定なしがいいかもしれません(同じサーバ名を持つサーバは立てられないため)
* `image_id` - サーバ立ち上げ時に指定するimage_id。ニフティクラウド公式のOSイメージでは動作しません。
* `key_name` - サーバ接続時に使用するSSHキー名。[コントロールパネルで設定した値](http://cloud.nifty.com/help/netsec/ssh_key.htm)を指定して下さい。
* `zone` - ニフティクラウドのゾーン。例)"east-12"
* `instance_ready_timeout` - インスタンス起動実行からタイムアウトとなるまでの秒数。デフォルトは300秒。
* `instance_type` - サーバタイプ。例)"small2"。指定がない場合のデフォルト値は"mini"。
* `firewall` - Firewall名。
* `password` - rootのパスワードとして設定したい値

上記のパラメータはVagrantfile中で以下のように設定することができます。


```
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :niftycloud do |niftycloud, override|
    niftycloud.access_key_id = ENV["NIFTY_CLOUD_ACCESS_KEY"] || "foo"
    niftycloud.secret_access_key = ENV["NIFTY_CLOUD_SECRET_KEY"] || "bar"
  end
end
```

トップレベルの設定に加えて、リージョン/ゾーン特有の設定値を使用したい場合にはVagrantfile中で`zone_config`を使用することもできます。

記述は以下のようになります。


```
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :niftycloud do |niftycloud, override|
    niftycloud.access_key_id = "foo"
    niftycloud.secret_access_key = "bar"
    niftycloud.zone = "east-12" # ここでどのゾーンで立ち上げるか決定
    
    niftycloud.key_name = "vagrantkey"
    niftycloud.firewall = "test"
    niftycloud.password = "password"
    override.ssh.username = "vagrant"
    override.ssh.private_key_path = "/path/to/private_key.pem"

    # シンプルな書き方
    niftycloud.zone_config "east-13", :instance_type => "small"

    # より多くの設定を上書きしたい場合
    niftycloud.zone_config "east-13" do |zone|
      zone.image_id = 21
      zone.instance_type = "small"
      zone.key_name = "vagrantkey2"
    end
  end
end
```

zone_configブロックでリージョン/ゾーン特有の設定を指定した場合、そのリージョン/ゾーンでサーバインスタンスを立ち上げる際にはトップレベルの設定値を上書きします。

指定していない設定項目についてはトップレベルの設定値を継承します。

### ニフティクラウドのリージョン切り替え
ニフティクラウドのリージョン切り替えについてはVagrantfile中だけでは設定できません。

環境変数`NIFTY_CLOUD_ENDPOINT_URL`に[適切なリクエスト先エンドポイント](http://cloud.nifty.com/api/endpoint.htm)を指定してやる必要があります。

以下のコマンドを実行するか、.bashrcや.zshrc等に追記するなどして下さい。

```
# 東日本リージョンでAPI最新版を使用
export NIFTY_CLOUD_ENDPOINT_URL='https://east-1.cp.cloud.nifty.com/api/'
# 西日本リージョンでAPI最新版を使用
export NIFTY_CLOUD_ENDPOINT_URL='https://west-1.cp.cloud.nifty.com/api/'
```

### ニフティクラウドのサーバ起動時スクリプトのサポート
ニフティクラウドの[サーバ起動時スクリプト](http://cloud.nifty.com/service/svscript.htm)をサポートしています。

以下のように指定して下さい。

```
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider "niftycloud" do |niftycloud|
    # Option 1: 1行で指定
    niftycloud.user_data = "#!/bin/bash\necho 'got user data' > /tmp/user_data.log\necho"

    # Option 2: ファイルから読み込む
    niftycloud.user_data = File.read("user_data.txt")
  end
end
```

## VagrantのNetwork機能への対応


Vagrantの`config.vm.network`で設定可能なネットワーク機能については、`vagrant-niftycloud`ではサポートしていません。 

## フォルダの同期

フォルダの同期についてはshell、chef、puppetといったVagrantのprovisionersを動作させるための最低限のサポートとなります。

`vagrant up`、`vagrant provision`コマンドが実行された場合、
このプラグインは`rsync`を使用しSSH経由でローカル→リモートサーバへの単方向同期を行います。


## 開発

`vagrant-niftycloud`プラグインをこのレポジトリからgit cloneした後、[Bundler](http://gembundler.com) を使用して必要なgem等のインストールを行なって下さい。

```
$ bundle
```

上記コマンド実行後、以下のコマンドにより`rake`を使用したユニットテストを実行することができます。

```
$ bundle exec rake
```

ユニットテストが通った場合、プラグインを動作させる準備が整います。

プラグインをVagrant実行環境にインストールしなくても以下の操作で実行することが可能です。

* トップレベルディレクトリに`Vagrantfile` を作成する(gitignoreしています)
* bundle execコマンドにより実行


```
$ bundle exec vagrant up --provider=niftycloud
```

## License

[vagrant-aws](https://github.com/mitchellh/vagrant-aws) をベースにニフティクラウド向けに修正を加えたものです。 オリジナルに準じて MIT License を適用します。
