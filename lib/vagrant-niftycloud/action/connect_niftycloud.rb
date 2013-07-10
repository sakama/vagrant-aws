require "NIFTY"
require "log4r"

module VagrantPlugins
  module NiftyCloud
    module Action
      # This action connects to NiftyCloud, verifies credentials work, and
      # puts the NiftyCloud connection object into the `:niftycloud_compute` key
      # in the environment.
      class ConnectNiftyCloud
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_niftycloud::action::connect_niftycloud")
        end

        def call(env)
          # Get the region we're going to booting up in
          region = env[:machine].provider_config.region

          # Get the configs
          region_config     = env[:machine].provider_config.get_region_config(region)

          # Build the fog config
          niftycloud_config = {
            :access_key => region_config.access_key_id,
            :secret_key => region_config.secret_access_key
          }

          @logger.info("Connecting to NiftyCloud...")
          env[:niftycloud_compute] = NIFTY::Cloud::Base.new(niftycloud_config)

          @app.call(env)
        end
      end
    end
  end
end
