# -*- coding: utf-8 -*-
require "log4r"

module VagrantPlugins
  module NiftyCloud
    module Action
      # This action reads the SSH info for the machine and puts it into the
      # `:machine_ssh_info` key in the environment.
      class ReadSSHInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_niftycloud::action::read_ssh_info")
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(env[:niftycloud_compute], env[:machine])

          @app.call(env)
        end

        def read_ssh_info(niftycloud, machine)
          return nil if machine.id.nil?

          # Find the machine
          # 例外の定義は以下参照
          # http://cloud.nifty.com/api/sdk/rdoc/
          begin
            server = niftycloud.get(machine)
            # Read the DNS info
            return {
              :host => server.ipAddress,
              :port => 22
            }
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
            # The machine can't be found
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            machine.id = nil
            return nil
          end
        end
      end
    end
  end
end
