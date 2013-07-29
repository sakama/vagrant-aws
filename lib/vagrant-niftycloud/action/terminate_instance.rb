# -*- coding: utf-8 -*-
require "log4r"

module VagrantPlugins
  module NiftyCloud
    module Action
      # This terminates the running instance.
      class TerminateInstance
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_niftycloud::action::terminate_instance")
        end

        def call(env)

          # 例外の定義は以下参照
          # http://cloud.nifty.com/api/sdk/rdoc/
          begin
            # terminate処理
            response = env[:niftycloud_compute].delete(env)
            env[:machine].id = nil

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
            raise Errors::NiftyCloudResponseError,
              :code    => e.error_code,
              :message => e.error_message
          end
        end
      end
    end
  end
end
