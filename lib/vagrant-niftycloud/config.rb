require "vagrant"

module VagrantPlugins
  module NiftyCloud
    class Config < Vagrant.plugin("2", :config)
      # The access key ID for accessing NiftyCloud.
      #
      # @return [String]
      attr_accessor :access_key_id

      # The ID of the AMI to use.
      #
      # @return [String]
      attr_accessor :image_id

      # The availability zone to launch the instance into. If nil, it will
      # use the default for your account.
      #
      # @return [String]
      attr_accessor :availability_zone

      # The timeout to wait for an instance to become ready.
      #
      # @return [Fixnum]
      attr_accessor :instance_ready_timeout

      # The type of instance to launch, such as "m1.small"
      #
      # @return [String]
      attr_accessor :instance_type

      # The name of the keypair to use.
      #
      # @return [String]
      attr_accessor :key_name

      # The secret access key for accessing NiftyCloud.
      #
      # @return [String]
      attr_accessor :secret_access_key

      # The security groups to set on the instance. For VPC this must
      # be a list of IDs. For NiftyCloud, it can be either.
      #
      # @return [Array<String>]
      attr_accessor :security_groups

      # The user data string
      #
      # @return [String]
      attr_accessor :user_data

      def initialize(region_specific=false)
        @access_key_id      = UNSET_VALUE
        @image_id           = UNSET_VALUE
        @availability_zone  = UNSET_VALUE
        @instance_ready_timeout = UNSET_VALUE
        @instance_type      = UNSET_VALUE
        @key_name           = UNSET_VALUE
        @secret_access_key  = UNSET_VALUE
        @security_groups    = UNSET_VALUE
        @user_data          = UNSET_VALUE

        # Internal state (prefix with __ so they aren't automatically
        # merged)
        @__compiled_region_configs = {}
        @__finalized = false
        @__region_config = {}
        @__region_specific = region_specific
      end

      # Allows region-specific overrides of any of the settings on this
      # configuration object. This allows the user to override things like
      # image_id and key name for regions. Example:
      #
      #     niftycloud.region_config "east-12" do |region|
      #       region.image_id = 21
      #       region.key_name = "company-east12"
      #     end
      #
      # @param [String] region The region name to configure.
      # @param [Hash] attributes Direct attributes to set on the configuration
      #   as a shortcut instead of specifying a full block.
      # @yield [config] Yields a new Nifty Cloud configuration.
      def region_config(region, attributes=nil, &block)
        # Append the block to the list of region configs for that region.
        # We'll evaluate these upon finalization.
        @__region_config[region] ||= []

        # Append a block that sets attributes if we got one
        if attributes
          attr_block = lambda do |config|
            config.set_options(attributes)
          end

          @__region_config[region] << attr_block
        end

        # Append a block if we got one
        @__region_config[region] << block if block_given?
      end

      #-------------------------------------------------------------------
      # Internal methods.
      #-------------------------------------------------------------------

      def merge(other)
        super.tap do |result|
          # Copy over the region specific flag. "True" is retained if either
          # has it.
          new_region_specific = other.instance_variable_get(:@__region_specific)
          result.instance_variable_set(
            :@__region_specific, new_region_specific || @__region_specific)

          # Go through all the region configs and prepend ours onto
          # theirs.
          new_region_config = other.instance_variable_get(:@__region_config)
          @__region_config.each do |key, value|
            new_region_config[key] ||= []
            new_region_config[key] = value + new_region_config[key]
          end

          # Set it
          result.instance_variable_set(:@__region_config, new_region_config)
        end
      end

      def finalize!
        # Try to get access keys from standard NiftyCloud environment variables; they
        # will default to nil if the environment variables are not present.
        @access_key_id     = ENV['NIFTY_ACCESS_KEY'] if @access_key_id     == UNSET_VALUE
        @secret_access_key = ENV['NIFTY_SECRET_KEY'] if @secret_access_key == UNSET_VALUE

        # AMI must be nil, since we can't default that
        @image_id = nil if @image_id == UNSET_VALUE

        # Set the default timeout for waiting for an instance to be ready
        @instance_ready_timeout = 120 if @instance_ready_timeout == UNSET_VALUE

        # Default instance type is an mini
        @instance_type = "mini" if @instance_type == UNSET_VALUE

        # Keypair defaults to nil
        @key_name = nil if @key_name == UNSET_VALUE

        @availability_zone = nil if @availability_zone == UNSET_VALUE

        # The security groups are empty by default.
        @security_groups = [] if @security_groups == UNSET_VALUE

        # User Data is nil by default
        @user_data = nil if @user_data == UNSET_VALUE

        if !@__region_specific
          @__region_config.each do |region, blocks|
            config = self.class.new(true).merge(self)

            # Execute the configuration for each block
            blocks.each { |b| b.call(config) }

            # The region name of the configuration always equals the
            # region config name:
            config.region = region

            # Finalize the configuration
            config.finalize!

            # Store it for retrieval
            @__compiled_region_configs[region] = config
          end
        end

        # Mark that we finalized
        @__finalized = true
      end

      def validate(machine)
        errors = _detected_errors

        errors << I18n.t("vagrant_niftycloud.config.region_required") if @region.nil?

        if @region
          # Get the configuration for the region we're using and validate only
          # that region.
          config = get_region_config(@region)

          if !config.use_iam_profile
            errors << I18n.t("vagrant_niftycloud.config.access_key_id_required") if \
              config.access_key_id.nil?
            errors << I18n.t("vagrant_niftycloud.config.secret_access_key_required") if \
              config.secret_access_key.nil?
          end

          errors << I18n.t("vagrant_niftycloud.config.image_id_required") if config.image_id.nil?
        end

        { "NiftyCloud Provider" => errors }
      end

      # This gets the configuration for a specific region. It shouldn't
      # be called by the general public and is only used internally.
      def get_region_config(name)
        if !@__finalized
          raise "Configuration must be finalized before calling this method."
        end

        # Return the compiled region config
        @__compiled_region_configs[name] || self
      end
    end
  end
end
