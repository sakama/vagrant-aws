# Vagrant NiftyCloud Provider

`開発中！まだ動作しません！！`

[Vagrant](http://www.vagrantup.com) 1.2以降のバージョンで[ニフティクラウド](http://cloud.nifty.com/)
を操作するためのprovider機能を追加するプラグインです。

Vagrantでニフティクラウド上のサーバインスタンスの制御や[Chef](http://www.opscode.com/chef/) / [Puppet](https://puppetlabs.com/) / [Fabric](http://docs.fabfile.org/)等を使ったサーバのprovisioningが可能となります。

**注意:** このプラグインはVagrant 1.2以降に対応しています。

## 機能

* ニフティクラウド上のサーバインスタンスの起動
* Vagrantから起動したインスタンスへのSSH
* Chef/Puppet/Fabric等を使用したインスタンスのprovisioning
* `rsync`を使用したcookbook等の転送

## Quick Start

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


```
$ vagrant up --provider=niftycloud
```


上の記述はCentOS 6.3 64bit Plainのサーバインスタンスを立ち上げるための記述です。

SSH接続やcookbook等を使ったサーバのprovisioningに失敗する場合、以下のような理由が考えられます。

* SSHオプションが正しくない
* 正しい秘密鍵が指定されていない
* 秘密鍵のパーミッションが正しくない
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
* `image_id` - サーバ立ち上げ時に指定するimage_id。([後述](https://github.com/sakama/vagrant-niftycloud#image_id))
* `key_name` - サーバ接続時に使用するSSHキー名。[コントロールパネルで設定した値](http://cloud.nifty.com/help/netsec/ssh_key.htm)を指定して下さい。
* `availability_zone` - ニフティクラウドのゾーン。例)"east-12"
* `instance_ready_timeout` - インスタンス起動実行からタイムアウトとなるまでの秒数。デフォルトは120秒です。
* `instance_type` - サーバタイプ。例)"small2"。指定がない場合のデフォルト値は"mini"です。
* `secret_access_key` - ニフティクラウドAPI経由でアクセスするためのSecretAccessKey。[コントロールパネルから取得した値](http://cloud.nifty.com/help/status/api_key.htm)を指定して下さい。
* `security_groups` - Firewall名。

上記のパラメータはVagrantfile中で以下のように設定することができます。


```
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :niftycloud do |niftycloud|
    niftycloud.access_key_id = ENV["NIFTY_CLOUD_ACCESS_KEY"] || "foo"
    niftycloud.secret_access_key = ENV["NIFTY_CLOUD_SECRET_KEY"] || "bar"
  end
end
```

トップレベルの設定に加えて、リージョン/ゾーン特有の設定値を使用したい場合にはVagrantfile中で`region_config`を使用することもできます。

記述は以下のようになります。


```
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :niftycloud do |niftycloud|
    niftycloud.access_key_id = "foo"
    niftycloud.secret_access_key = "bar"
    niftycloud.region = "east-12"
    niftycloud.key_name = "vagrantkey"

    # シンプルな書き方
    niftycloud.region_config "east-12", :image_id => 26

    # より多くの設定を上書きしたい場合
    niftycloud.region_config "east-13" do |region|
      region.image_id = 21
      region.instance_type = small
      region.key_name = "vagrantkey2"
    end
  end
end
```

region_configブロックでリージョン/ゾーン特有の設定を指定した場合、そのリージョン/ゾーンでサーバインスタンスを立ち上げる際にはトップレベルの設定値を上書きします。

指定していない設定項目についてはトップレベルの設定値を継承します。

## 主要なimage_idについて

以下にニフティから提供されている[公式イメージ](http://cloud.nifty.com/service/spec.htm)とそのimage_idを記載します。

`全てのOS・ディストリビューションでの動作確認は行なっていません。`

自分で作成したサーバイメージを使用する場合等でimage_idを確認したい時には[ニフティクラウドAPI](http://cloud.nifty.com/api/rest/reference.htm)の[DescribeImages](http://cloud.nifty.com/api/rest/DescribeImages.htm)を使用すると確認できます。

[ニフティクラウドSDK for Ruby](http://cloud.nifty.com/api/sdk/#ruby)や[ニフティクラウド CLI](http://cloud.nifty.com/api/cli/)、[knife-nc](https://github.com/tily/ruby-knife-nc)等を使うとより簡単です。

image_id    | OS・ディストリビューション             | 
------------|------------------------------------|
1           | CentOS 5.3 32bit Plain             | 
2           | CentOS 5.3 64bit Plain             | 
3           | Red Hat Enterprise Linux 5.3 32bit |
4           | Red Hat Enterprise Linux 5.3 64bit |
6           | CentOS 5.3 32bit Server            | 
7           | CentOS 5.3 64bit Server            | 
12          | Microsoft Windows Server 2008 R2   | 
13          | CentOS 5.6 64bit Plain             | 
14          | CentOS 5.6 64bit Server            |
16          | Microsoft SQLServer 2008 R2        |
17          | Ubuntu 10.04 64bit Plain           |
21          | CentOS 6.2 64bit Plain             |
22          | Red Hat Enterprise Linux 5.8 64bit |
24          | Red Hat Enterprise Linux 6.3 64bit |
26          | CentOS 6.3 64bit Plain             |
27          | Ubuntu 12.04 64bit Plain           |


## VagrantのNetwork機能への対応


Vagrantの`config.vm.network`で設定可能なネットワーク機能については、`vagrant-niftycloud`ではサポートしていません。 

## フォルダの同期

フォルダの同期についてはshell、chef、puppetといったVagrantのprovisionersを動作させるための最低限のサポートとなります。

`vagrant up`、`vagrant reload`、`vagrant provision`コマンドが実行された場合、
このプラグインは`rsync`を使用しSSH経由でローカル→リモートサーバへの単方向同期を行います。

### Tags機能への対応

[vagrant-aws](https://github.com/mitchellh/vagrant-aws)には起動したインスタンスに任意のTagsを付与するためのオプションが存在しますが、ニフティクラウド自体がTags機能に対応していないため未対応となります。

### サーバ起動時スクリプト

以下のようにニフティクラウドの[サーバ起動時スクリプト](http://cloud.nifty.com/service/svscript.htm)を使用したインスタンスの立ち上げが可能です。

ChefやFabricを使って立ち上げる場合、一般的には指定しないことが多いと思います。

```
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider "niftycloud" do |niftycloud|
    # オプションの書き方1
    niftycloud.user_data = "#!/bin/bash\necho 'got user data' > /tmp/user_data.log\necho"

    # オプションの書き方2 ファイルから読み込む
    niftycloud.user_data = File.read("user_data.txt")
  end
end
```

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
