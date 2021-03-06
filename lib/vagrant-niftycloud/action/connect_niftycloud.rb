# -*- coding: utf-8 -*-
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
          # Get the zone we're going to booting up in
          zone = env[:machine].provider_config.zone

          # Get the configs
          zone_config     = env[:machine].provider_config.get_zone_config(zone)

          # Build the fog config
          niftycloud_config = {
            :access_key => zone_config.access_key_id,
            :secret_key => zone_config.secret_access_key
          }

          # 例外の定義は以下参照
          # http://cloud.nifty.com/api/sdk/rdoc/
          begin
            @logger.info("Connecting to NiftyCloud...")
            env[:niftycloud_compute] = Servers::Servers.new(niftycloud_config)
          rescue NIFTY::ConfigurationError => e
            raise Errors::NiftyCloudConfigurationError,
              :message => e.message
          rescue NIFTY::ArgumentError => e
            raise Errors::NiftyCloudArgumentError,
              :message => e.message
          rescue NIFTY::ResponseFormatError => e
            raise Errors::NiftyCloudResponseFormatError,
              :message => e.message
          rescue NIFTY::ResponseError => e
            raise Errors::NiftyCloudResponseError,
              :code    => e.error_code,
              :message => e.error_message
          end

          @app.call(env)
        end
      end
    end
  end
end
