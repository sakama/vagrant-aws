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

      # The NiftyCloud endpoint to connect to
      #
      # @return [String]
      attr_accessor :endpoint

      # The version of the NiftyCloud api to use
      #
      # @return [String]
      attr_accessor :version

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
        @endpoint           = UNSET_VALUE
        @version            = UNSET_VALUE
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

	@availability_zone = nil if @availability_zone == UNSET_VALUE
        @endpoint = nil if @endpoint == UNSET_VALUE
        @version = nil if @version == UNSET_VALUE

        # The security groups are empty by default.
        @security_groups = [] if @security_groups == UNSET_VALUE

        # User Data is nil by default
        @user_data = nil if @user_data == UNSET_VALUE

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
