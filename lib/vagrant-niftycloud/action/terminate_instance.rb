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
            env[:ui].info(I18n.t("vagrant_niftycloud.terminating"))

            # 起動直後等、terminate処理できないステータスの場合一旦待つ
            server = env[:niftycloud_compute].describe_instances(:instance_id => env[:machine].id).reservationSet.item.first.instancesSet.item.first
            while server.instanceState.name == 'pending'
              sleep 5
              server = env[:niftycloud_compute].describe_instances(:instance_id => env[:machine].id).reservationSet.item.first.instancesSet.item.first
            end

            attribute = env[:niftycloud_compute].describe_instance_attribute(:instance_id => env[:machine].id, :attribute => 'disableApiTermination')
            if attribute.disableApiTermination.value == 'false'
              # AWSのように即terminateができないため念のため一旦stopする
              # TODO API経由でのterminate不可の場合を考慮する必要があるか
              server = env[:niftycloud_compute].describe_instances(:instance_id => env[:machine].id).reservationSet.item.first.instancesSet.item.first
              if server.instanceState.name != 'stopped'
                env[:niftycloud_compute].stop_instances(:instance_id => env[:machine].id, :force => true)
                while server.instanceState.name != 'stopped'
                  sleep 5
                  server = env[:niftycloud_compute].describe_instances(:instance_id => env[:machine].id).reservationSet.item.first.instancesSet.item.first
                end
              end
            end

            # terminate処理
            server = env[:niftycloud_compute].describe_instances(:instance_id => env[:machine].id).reservationSet.item.first.instancesSet.item.first
            if server.instanceState.name == 'stopped'
              response = env[:niftycloud_compute].terminate_instances(:instance_id => env[:machine].id)
              env[:machine].id = nil

              @app.call(env)
            end
          rescue NIFTY::ConfigurationError => e
            raise VagrantPlugins::NiftyCloud::Errors::NiftyCloudConfigurationError,
              :code    => e.error_code,
              :message => e.error_message
            ui.error("Could not locate server '#{env[:machine].id}'.  Please verify it was provisioned in the current zone.")
          rescue NIFTY::ArgumentError => e
            raise VagrantPlugins::NiftyCloud::Errors::NiftyCloudArgumentError,
              :code    => e.error_code,
              :message => e.error_message
          end
        end
      end
    end
  end
end
