# Vagrant NiftyCloud Provider

This is a [Vagrant](http://www.vagrantup.com) 1.2+ plugin that adds an [NiftyCloud](http://cloud.nifty.com/)
provider to Vagrant, allowing Vagrant to control and provision machines in
EC2 and VPC.

**NOTE:** This plugin requires Vagrant 1.2+,

## Features

* Boot NiftyCloudinstances.
* SSH into the instances.
* Provision the instances with any built-in Vagrant provisioner.
* Minimal synced folder support via `rsync`.
* Define region-specifc configurations so Vagrant can manage machines
  in multiple regions.

## Usage

Install using standard Vagrant 1.1+ plugin installation methods. After
installing, `vagrant up` and specify the `niftycloud` provider. An example is
shown below.

```
$ vagrant plugin install vagrant-niftycloud
...
$ vagrant up --provider=niftycloud
...
```

Of course prior to doing this, you'll need to obtain an NiftyCloud-compatible
box file for Vagrant.

## Quick Start

After installing the plugin (instructions above), the quickest way to get
started is to actually use a dummy NiftyCloud box and specify all the details
manually within a `config.vm.provider` block. So first, add the dummy
box using any name you want:

```
$ vagrant box add dummy https://github.com/mitchellh/vagrant-niftycloud/raw/master/dummy.box
...
```

And then make a Vagrantfile that looks like the following, filling in
your information where necessary.

```
Vagrant.configure("2") do |config|
  config.vm.box = "dummy"

  config.vm.provider :niftycloud do |niftycloud, override|
    niftycloud.access_key_id = "YOUR KEY"
    niftycloud.secret_access_key = "YOUR SECRET KEY"
    niftycloud.keypair_name = "KEYPAIR NAME"

    niftycloud.ami = "ami-7747d01e"

    override.ssh.username = "root"
    override.ssh.private_key_path = "PATH TO YOUR PRIVATE KEY"
  end
end
```

And then run `vagrant up --provider=niftycloud`.

This will start an Ubuntu 12.04 instance in the us-east-1 region within
your account. And assuming your SSH information was filled in properly
within your Vagrantfile, SSH and provisioning will work as well.

Note that normally a lot of this boilerplate is encoded within the box
file, but the box file used for the quick start, the "dummy" box, has
no preconfigured defaults.

If you have issues with SSH connecting, make sure that the instances
are being launched with a security group that allows SSH access.

## Box Format

Every provider in Vagrant must introduce a custom box format. This
provider introduces `niftycloud` boxes. You can view an example box in
the [example_box/ directory](https://github.com/sakama/vagrant-niftycloud/tree/master/example_box).
That directory also contains instructions on how to build a box.

The box format is basically just the required `metadata.json` file
along with a `Vagrantfile` that does default settings for the
provider-specific configuration for this provider.

## Configuration

This provider exposes quite a few provider-specific configuration options:

* `access_key_id` - The access key for accessing NiftyCloud
* `ami` - The AMI id to boot, such as "ami-12345678"
* `availability_zone` - The availability zone within the region to launch
  the instance. If nil, it will use the default set by Amazon.
* `instance_ready_timeout` - The number of seconds to wait for the instance
  to become "ready" in NiftyCloud. Defaults to 120 seconds.
* `instance_type` - The type of instance, such as "m1.small". The default
  value of this if not specified is "m1.small".
* `keypair_name` - The name of the keypair to use to bootstrap AMIs
   which support it.
* `private_ip_address` - not to use
* `region` - The region to start the instance in, such as "us-east-1"
* `secret_access_key` - The secret access key for accessing NiftyCloud
* `security_groups` - An array of security groups for the instance.
  IDs.
* `subnet_id` - The subnet to boot the instance into, for VPC.
* `tags` - A hash of tags to set on the machine.
* `use_iam_profile` - If true, will use [IAM profiles]
  for credentials.

These can be set like typical provider-specific configuration:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :niftycloud do |niftycloud|
    niftycloud.access_key_id = "foo"
    niftycloud.secret_access_key = "bar"
  end
end
```

In addition to the above top-level configs, you can use the `region_config`
method to specify region-specific overrides within your Vagrantfile. Note
that the top-level `region` config must always be specified to choose which
region you want to actually use, however. This looks like this:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :niftycloud do |niftycloud|
    niftycloud.access_key_id = "foo"
    niftycloud.secret_access_key = "bar"
    niftycloud.region = "us-east-1"

    # Simple region config
    niftycloud.region_config "east-13", :ami => "ami-12345678"

    # More comprehensive region config
    niftycloud.region_config "east-13" do |region|
      region.ami = "ami-87654321"
      region.keypair_name = "company-west"
    end
  end
end
```

The region-specific configurations will override the top-level
configurations when that region is used. They otherwise inherit
the top-level configurations, as you would probably expect.

## Networks

Networking features in the form of `config.vm.network` are not
supported with `vagrant-niftycloud`, currently. If any of these are
specified, Vagrant will emit a warning, but will otherwise boot
the NiftyCloud machine.

## Synced Folders

There is minimal support for synced folders. Upon `vagrant up`,
`vagrant reload`, and `vagrant provision`, the NiftyCloud provider will use
`rsync` (if available) to uni-directionally sync the folder to
the remote machine over SSH.

This is good enough for all built-in Vagrant provisioners (shell,
chef, and puppet) to work!

## Other Examples

### Tags

To use tags, simply define a hash of key/value for the tags you want to associate to your instance, like:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider "niftycloud" do |niftycloud|
    niftycloud.tags = {
	  'Name' => 'Some Name',
	  'Some Key' => 'Some Value'
    }
  end
end
```

### User data

You can specify user data for the instance being booted.

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider "niftycloud" do |niftycloud|
    # Option 1: a single string
    niftycloud.user_data = "#!/bin/bash\necho 'got user data' > /tmp/user_data.log\necho"

    # Option 2: use a file
    niftycloud.user_data = File.read("user_data.txt")
  end
end
```

## Development

To work on the `vagrant-niftycloud` plugin, clone this repository out, and use
[Bundler](http://gembundler.com) to get the dependencies:

```
$ bundle
```

Once you have the dependencies, verify the unit tests pass with `rake`:

```
$ bundle exec rake
```

If those pass, you're ready to start developing the plugin. You can test
the plugin without installing it into your Vagrant environment by just
creating a `Vagrantfile` in the top level of this directory (it is gitignored)
that uses it, and uses bundler to execute Vagrant:

```
$ bundle exec vagrant up --provider=niftycloud
```
