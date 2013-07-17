# Vagrant NiftyCloud Provider

`開発中！まだ動作しません！！`

[Vagrant](http://www.vagrantup.com) 1.2以降のバージョンで[ニフティクラウド](http://cloud.nifty.com/)
を操作するためのprovider機能を追加するプラグインです。

Vagrantでニフティクラウド上のサーバインスタンスの制御や[Chef](http://www.opscode.com/chef/)や[Puppet](https://puppetlabs.com/) 等を使ったサーバのprovisioningが可能となります。

Chef以外の動作確認は行なっていませんが、プラグインで行なっているのはSSH実行可能な状態にすることとrsyncによるファイル転送だけなので、vagrantでサポートされているものであれば動作するのではないかと思います。

**注意:** このプラグインはVagrant 1.2以降に対応しています。

## 機能

* ニフティクラウド上のサーバインスタンスの起動
* Vagrantから起動したインスタンスへのSSH
* Chef/Puppet等を使用したインスタンスのprovisioning
* `rsync`を使用したcookbook等の転送

## Quick Start

### プラグインのインストール

まずVagrant 1.2以降をインストールして下さい。

vagrant upを実行する前に通常のVagrant使用時と同じようにboxファイルをVagrantに追加する必要があります。

自分でboxファイルを作成するかこちらで用意しているboxファイルを使用して、任意の名前でダミーのboxを追加して下さい。

```
$ git clone https://github.com/sakama/vagrant-niftycloud.git
$ cd vagrant-niftycloud
$ bundle install
$ bundle exec rake build
$ vagrant plugin install pkg/vagrant-niftycloud-0.1.0.dev.gem
$ vagrant box add dummy https://github.com/sakama/vagrant-niftycloud/raw/master/dummy.box
...
```

### OSイメージの作成

Vagrant自体の仕様により、以下の制約があります。

* サーバに接続するvagrantユーザがパスワードなしでsudo実行できる必要がある (rootユーザではprovisioning実行に失敗します)
* sudoがttyなしで実行できる必要がある
* サーバに接続する際のSSH秘密鍵はパスフレーズが空で設定されている必要がある(rsyncでのファイル同期に失敗します)

以上の理由により、`ニフティクラウド公式のOSイメージでは動作しません`

上記条件をクリアしたサーバイメージをプライベートイメージ等を用意する必要があります。

OSイメージ作成の手順は以下のようになります。

```
## rootで実行
# groupadd vagrant
# useradd vagrant -g vagrant -G wheel
# passwd vagrant

# su - vagrant
## vagrantユーザで実行
$ ssh-keygen -t rsa
$ mv id_rsa.pub authorized_keys(id_rsaをローカルに保存する=接続する際のSSH秘密鍵となる)

## rootで実行
# visudo
# Defaults specificationをコメントアウト
# 最終行に以下を追加
# vagrant        ALL=(ALL)       NOPASSWD: ALL
```

作成したイメージのimage_idをVagrantfile内で指定する必要があります。

image_idについては[ニフティクラウドSDK for Ruby](http://cloud.nifty.com/api/sdk/#ruby)や[ニフティクラウド CLI](http://cloud.nifty.com/api/cli/) 等を使うと確認可能です。

### Vagrantfileの作成

Vagrantfileを以下のような内容で作成します。

Vagrantfileの`config.vm.provider`ブロックで各種パラメータを指定して下さい。

```
Vagrant.configure("2") do |config|
  config.vm.box = "dummy"

  config.vm.provider :niftycloud do |niftycloud, override|
    niftycloud.access_key_id = ENV["NIFTY_CLOUD_ACCESS_KEY"] || "<Your Access Key ID>"
    niftycloud.secret_access_key = ENV["NIFTY_CLOUD_SECRET_KEY"] || "<Your Secret Access Key>"

    niftycloud.image_id = "26"
    niftycloud.key_name = "<YOUR SSH KEY NAME>"
    override.ssh.username = "root"
    override.ssh.private_key_path = "PATH TO YOUR PRIVATE KEY"
  end
end
```

以上の手順で`vagrant up`コマンドのproviderオプションに`niftycloud`を指定できるようになります。

### コマンド

```

# サーバ立ちあげ、provisioningの実行
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

boxフォーマットには`metadata.json`が必要です。

このjsonファイル中に指定された値は`Vagrantfile` と同様に、providerとしてniftycloudを指定した場合のデフォルト値として扱われます。


## 設定

以下の様なパラメータに対応しています。


* `access_key_id` - ニフティクラウドのAccessKey。[コントロールパネルから取得した値](http://cloud.nifty.com/help/status/api_key.htm)を指定して下さい。
* `image_id` - サーバ立ち上げ時に指定するimage_id。ニフティクラウド公式のOSイメージでは動作しません。
* `key_name` - サーバ接続時に使用するSSHキー名。[コントロールパネルで設定した値](http://cloud.nifty.com/help/netsec/ssh_key.htm)を指定して下さい。
* `zone` - ニフティクラウドのゾーン。例)"east-12"
* `instance_ready_timeout` - インスタンス起動実行からタイムアウトとなるまでの秒数。デフォルトは300秒です。
* `instance_type` - サーバタイプ。例)"small2"。指定がない場合のデフォルト値は"mini"です。
* `secret_access_key` - ニフティクラウドAPI経由でアクセスするためのSecretAccessKey。[コントロールパネルから取得した値](http://cloud.nifty.com/help/status/api_key.htm)を指定して下さい。
* `firewall` - Firewall名。

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
    niftycloud.zone = "east-12"
    niftycloud.key_name = "vagrantkey"
    niftycloud.firewall = "test"
    override.ssh.username = "root"
    override.ssh.private_key_path = "/path/to/private_key.pem"

    # シンプルな書き方
    niftycloud.zone_config "east-12", :image_id => 26

    # より多くの設定を上書きしたい場合
    niftycloud.zone_config "east-13" do |zone|
      zone.image_id = 21
      zone.instance_type = small
      zone.key_name = "vagrantkey2"
    end
  end
end
```

zone_configブロックでリージョン/ゾーン特有の設定を指定した場合、そのリージョン/ゾーンでサーバインスタンスを立ち上げる際にはトップレベルの設定値を上書きします。

指定していない設定項目についてはトップレベルの設定値を継承します。


## VagrantのNetwork機能への対応


Vagrantの`config.vm.network`で設定可能なネットワーク機能については、`vagrant-niftycloud`ではサポートしていません。 

## フォルダの同期

フォルダの同期についてはshell、chef、puppetといったVagrantのprovisionersを動作させるための最低限のサポートとなります。

`vagrant up`、`vagrant reload`、`vagrant provision`コマンドが実行された場合、
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

## ライセンス

[vagrant-aws](https://github.com/mitchellh/vagrant-aws) をベースに NIFTY Cloud 向けに修正を加えたものです。 オリジナルに準じて MITライセンス を適用します。
