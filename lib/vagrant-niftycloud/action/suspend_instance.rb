# -*- coding: utf-8 -*-
require "log4r"

module VagrantPlugins
  module NiftyCloud
    module Action
      # This suspend the running instance.
      class SuspendInstance
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_niftycloud::action::suspend_instance")
        end

        def call(env)

          # 例外の定義は以下参照
          # http://cloud.nifty.com/api/sdk/rdoc/
          begin
            env[:ui].info(I18n.t("vagrant_niftycloud.suspending"))

            # 起動直後等、stop処理できないステータスの場合一旦待つ
            server = env[:niftycloud_compute].describe_instances(:instance_id => env[:machine].id).reservationSet.item.first.instancesSet.item.first
            while server.instanceState.name == 'pending'
              sleep 5
              server = env[:niftycloud_compute].describe_instances(:instance_id => env[:machine].id).reservationSet.item.first.instancesSet.item.first
            end

            if server.instanceState.name != 'stopped'
              env[:niftycloud_compute].stop_instances(:instance_id => env[:machine].id, :force => false)
              while server.instanceState.name != 'stopped'
                sleep 5
                server = env[:niftycloud_compute].describe_instances(:instance_id => env[:machine].id).reservationSet.item.first.instancesSet.item.first
              end
            end

            @app.call(env)
          rescue NIFTY::ConfigurationError => e
            raise VagrantPlugins::NiftyCloud::Errors::NiftyCloudConfigurationError,
              :message => e.message
          rescue NIFTY::ArgumentError => e
            raise VagrantPlugins::NiftyCloud::Errors::NiftyCloudArgumentError,
              :message => e.message
          rescue NIFTY::ResponseError => e
            raise VagrantPlugins::NiftyCloud::Errors::NiftyCloudResponseError,
              :code    => e.error_code,
              :message => e.error_message
            ui.error("Could not locate server '#{env[:machine].id}'.  Please verify it was provisioned in the current zone.")
          end
        end
      end
    end
  end
end
