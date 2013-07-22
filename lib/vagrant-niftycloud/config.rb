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
      attr_accessor :instance_id

      # The ID of the AMI to use.
      #
      # @return [String]
      attr_accessor :image_id

      # The zone to launch the instance into. If nil, it will
      # use the default for your account.
      #
      # @return [String]
      attr_accessor :zone

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

      # The firewall to set on the instance.
      # be a list of IDs. For NiftyCloud, it can be either.
      #
      # @return [Array<String>]
      attr_accessor :firewall

      # The password string
      #
      # @return [String]
      attr_accessor :password

      # The user data string
      #
      # @return [String]
      attr_accessor :user_data

      def initialize(zone_specific=false)
        @access_key_id      = UNSET_VALUE
        @instance_id        = UNSET_VALUE
        @image_id           = UNSET_VALUE
        @zone               = UNSET_VALUE
        @instance_ready_timeout = UNSET_VALUE
        @instance_type      = UNSET_VALUE
        @key_name           = UNSET_VALUE
        @secret_access_key  = UNSET_VALUE
        @firewall           = UNSET_VALUE
        @password           = UNSET_VALUE
        @user_data          = UNSET_VALUE

        # Internal state (prefix with __ so they aren't automatically
        # merged)
        @__compiled_zone_configs = {}
        @__finalized = false
        @__zone_config = {}
        @__zone_specific = zone_specific
      end

      # Allows zone-specific overrides of any of the settings on this
      # configuration object. This allows the user to override things like
      # image_id and key name for zones. Example:
      #
      #     niftycloud.zone_config "east-12" do |zone|
      #       zone.image_id = 21
      #       zone.key_name = "company-east12"
      #     end
      #
      # @param [String] zone The zone name to configure.
      # @param [Hash] attributes Direct attributes to set on the configuration
      #   as a shortcut instead of specifying a full block.
      # @yield [config] Yields a new Nifty Cloud configuration.
      def zone_config(zone, attributes=nil, &block)
        # Append the block to the list of zone configs for that zone.
        # We'll evaluate these upon finalization.
        @__zone_config[zone] ||= []

        # Append a block that sets attributes if we got one
        if attributes
          attr_block = lambda do |config|
            config.set_options(attributes)
          end

          @__zone_config[zone] << attr_block
        end

        # Append a block if we got one
        @__zone_config[zone] << block if block_given?
      end

      #-------------------------------------------------------------------
      # Internal methods.
      #-------------------------------------------------------------------

      def merge(other)
        super.tap do |result|
          # Copy over the zone specific flag. "True" is retained if either
          # has it.
          new_zone_specific = other.instance_variable_get(:@__zone_specific)
          result.instance_variable_set(
            :@__zone_specific, new_zone_specific || @__zone_specific)

          # Go through all the zone configs and prepend ours onto
          # theirs.
          new_zone_config = other.instance_variable_get(:@__zone_config)
          @__zone_config.each do |key, value|
            new_zone_config[key] ||= []
            new_zone_config[key] = value + new_zone_config[key]
          end

          # Set it
          result.instance_variable_set(:@__zone_config, new_zone_config)
        end
      end

      def finalize!
        # Try to get access keys from standard NiftyCloud environment variables; they
        # will default to nil if the environment variables are not present.
        @access_key_id     = ENV['NIFTY_ACCESS_KEY'] if @access_key_id     == UNSET_VALUE
        @secret_access_key = ENV['NIFTY_SECRET_KEY'] if @secret_access_key == UNSET_VALUE

        @instance_id = nil if @instance_id == UNSET_VALUE

        # AMI must be nil, since we can't default that
        @image_id = nil if @image_id == UNSET_VALUE

        # Set the default timeout for waiting for an instance to be ready
        @instance_ready_timeout = 300 if @instance_ready_timeout == UNSET_VALUE

        # Default instance type is an mini
        @instance_type = "mini" if @instance_type == UNSET_VALUE

        # Keypair defaults to nil
        @key_name = nil if @key_name == UNSET_VALUE

        @zone = nil if @zone == UNSET_VALUE

        # The firewall are empty by default.
        @firewall = [] if @firewall == UNSET_VALUE

        # The password are empty by default.
        @password = [] if @password == UNSET_VALUE

        # User Data is nil by default
        @user_data = nil if @user_data == UNSET_VALUE

        if !@__zone_specific
          @__zone_config.each do |zone, blocks|
            config = self.class.new(true).merge(self)

            # Execute the configuration for each block
            blocks.each { |b| b.call(config) }

            # The zone name of the configuration always equals the
            # zone config name:
            config.zone = zone

            # Finalize the configuration
            config.finalize!

            # Store it for retrieval
            @__compiled_zone_configs[zone] = config
          end
        end

        # Mark that we finalized
        @__finalized = true
      end

      def validate(machine)
        errors = _detected_errors

        errors << I18n.t("vagrant_niftycloud.config.zone_required") if @zone.nil?

        if @zone
          # Get the configuration for the zone we're using and validate only
          # that zone.
          config = get_zone_config(@zone)

          errors << I18n.t("vagrant_niftycloud.config.access_key_id_required") if \
            config.access_key_id.nil?
          errors << I18n.t("vagrant_niftycloud.config.secret_access_key_required") if \
            config.secret_access_key.nil?

          errors << I18n.t("vagrant_niftycloud.config.image_id_required") if config.image_id.nil?
        end

        { "NiftyCloud Provider" => errors }
      end

      # This gets the configuration for a specific zone. It shouldn't
      # be called by the general public and is only used internally.
      def get_zone_config(name)
        if !@__finalized
          raise "Configuration must be finalized before calling this method."
        end

        # Return the compiled zone config
        @__compiled_zone_configs[name] || self
      end
    end
  end
end
