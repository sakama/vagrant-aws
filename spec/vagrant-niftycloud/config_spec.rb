require "vagrant-niftycloud/config"

describe VagrantPlugins::NiftyCloud::Config do
  let(:instance) { described_class.new }

  # Ensure tests are not affected by NiftyCloud credential environment variables
  before :each do
    ENV.stub(:[] => nil)
  end

  describe "defaults" do
    subject do
      instance.tap do |o|
        o.finalize!
      end
    end

    its("access_key_id")     { should be_nil }
    its("image_id")          { should be_nil }
    its("availability_zone") { should be_nil }
    its("instance_ready_timeout") { should == 120 }
    its("instance_type")     { should == "m1.small" }
    its("secret_access_key") { should be_nil }
    its("security_groups")   { should == [] }
    its("user_data")         { should be_nil }
  end

  describe "overriding defaults" do
    # I typically don't meta-program in tests, but this is a very
    # simple boilerplate test, so I cut corners here. It just sets
    # each of these attributes to "foo" in isolation, and reads the value
    # and asserts the proper result comes back out.
    [:access_key_id, :image_id, :availability_zone,
      :instance_ready_timeout, :instance_type, :secret_access_key,
      :security_groups, :user_data].each do |attribute|

      it "should not default #{attribute} if overridden" do
        instance.send("#{attribute}=".to_sym, "foo")
        instance.finalize!
        instance.send(attribute).should == "foo"
      end
    end
  end

  describe "getting credentials from environment" do
    context "without NiftyCloud credential environment variables" do
      subject do
        instance.tap do |o|
          o.finalize!
        end
      end

      its("access_key_id")     { should be_nil }
      its("secret_access_key") { should be_nil }
    end

    context "with NiftyCloud credential environment variables" do
      before :each do
        ENV.stub(:[]).with("NIFTY_ACCESS_KEY").and_return("access_key")
        ENV.stub(:[]).with("NIFTY_SECRET_KEY").and_return("secret_key")
      end

      subject do
        instance.tap do |o|
          o.finalize!
        end
      end

      its("access_key_id")     { should == "access_key" }
      its("secret_access_key") { should == "secret_key" }
    end
  end

  describe "region config" do
    let(:config_access_key_id)     { "foo" }
    let(:config_image_id)          { "foo" }
    let(:config_instance_type)     { "foo" }
    let(:config_secret_access_key) { "foo" }

    def set_test_values(instance)
      instance.access_key_id     = config_access_key_id
      instance.image_id          = config_image_id
      instance.instance_type     = config_instance_type
      instance.secret_access_key = config_secret_access_key
    end

    context "with no specific config set" do
      subject do
        # Set the values on the top-level object
        set_test_values(instance)

        # Finalize so we can get the region config
        instance.finalize!

      end

      its("access_key_id")     { should == config_access_key_id }
      its("image_id")          { should == config_image_id }
      its("instance_type")     { should == config_instance_type }
      its("secret_access_key") { should == config_secret_access_key }
    end

    context "with a specific config set" do
      its("access_key_id")     { should == config_access_key_id }
      its("image_id")          { should == config_image_id }
      its("instance_type")     { should == config_instance_type }
      its("secret_access_key") { should == config_secret_access_key }
    end

    describe "inheritance of parent config" do
      let(:region_name) { "hashi-region" }

      subject do
        # Set the values on a specific region
        instance.region_config region_name do |config|
          config.image_id = "child"
        end

        # Set some top-level values
        instance.access_key_id = "parent"
        instance.image_id = "parent"

        # Finalize and get the region
        instance.finalize!
        instance.get_region_config(region_name)
      end

      its("access_key_id") { should == "parent" }
      its("image_id")      { should == "child" }
    end

    describe "shortcut configuration" do
      subject do
        # Use the shortcut configuration to set some values
        instance.region_config "us-east-1", :image_id => "child"
        instance.finalize!
        instance.get_region_config("us-east-1")
      end

      its("image_id") { should == "child" }
    end

    describe "merging" do
      let(:first)  { described_class.new }
      let(:second) { described_class.new }
    end
  end
end
