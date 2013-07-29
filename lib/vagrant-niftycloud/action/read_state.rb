# -*- coding: utf-8 -*-
require "log4r"

module VagrantPlugins
  module NiftyCloud
    module Action
      # This action reads the state of the machine and puts it in the
      # `:machine_state_id` key in the environment.
      class ReadState
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_niftycloud::action::read_state")
        end

        def call(env)
          env[:machine_state_id] = read_state(env[:niftycloud_compute], env[:machine])

          @app.call(env)
        end

        def read_state(niftycloud, machine)
          return :not_created if machine.id.nil?

          # Find the machine
          # 例外の定義は以下参照
          # http://cloud.nifty.com/api/sdk/rdoc/
          begin
            server = niftycloud.get(machine)

            state = server.instanceState.name
            case state
            when 'suspending'
              @logger.info("Machine not found or terminated, assuming it got destroyed.")
              machine.id = nil
              return :not_created
            else
              @logger.debug("Server State #{state.to_sym}")
              return state.to_sym
            end
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
            machine.id = nil
            return :not_created
          end
        end
      end
    end
  end
end
