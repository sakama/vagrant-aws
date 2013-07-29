# -*- coding: utf-8 -*-
require "log4r"

module VagrantPlugins
  module NiftyCloud
    module Action
      # This resume the running instance.
      class ResumeInstance
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_niftycloud::action::resume_instance")
        end

        def call(env)

          # 例外の定義は以下参照
          # http://cloud.nifty.com/api/sdk/rdoc/
          begin
            env[:niftycloud_compute].start(env)

            @app.call(env)
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
            ui.error("Could not locate server '#{env[:machine].id}'.  Please verify it was provisioned in the current zone.")
            raise Errors::NiftyCloudResponseError,
              :code    => e.error_code,
              :message => e.error_message
          end
        end
      end
    end
  end
end
