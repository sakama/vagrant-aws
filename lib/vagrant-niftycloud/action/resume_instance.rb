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
            env[:ui].info(I18n.t("vagrant_niftycloud.resuming"))

            # 起動直後等、resume処理できないステータスの場合一旦待つ
            server = env[:niftycloud_compute].describe_instances(:instance_id => env[:machine].id).reservationSet.item.first.instancesSet.item.first
            while server.instanceState.name == 'pending'
              sleep 5
              server = env[:niftycloud_compute].describe_instances(:instance_id => env[:machine].id).reservationSet.item.first.instancesSet.item.first
            end

            if server.instanceState.name != 'running'
              env[:niftycloud_compute].start_instances(:instance_id => env[:machine].id)
              while server.instanceState.name != 'running'
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
          rescue NIFTY::ResponseFormatError => e
            raise VagrantPlugins::NiftyCloud::Errors::NiftyCloudResponseFormatError,
              :message => e.message
          rescue NIFTY::ResponseError => e
            ui.error("Could not locate server '#{env[:machine].id}'.  Please verify it was provisioned in the current zone.")
            raise VagrantPlugins::NiftyCloud::Errors::NiftyCloudResponseError,
              :code    => e.error_code,
              :message => e.error_message
          end
        end
      end
    end
  end
end
