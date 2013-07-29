# -*- coding: utf-8 -*-
require 'log4r'
require 'NIFTY'

module VagrantPlugins
  module NiftyCloud
    module Servers
      class Servers

        def initialize(niftycloud_config)
          if !ENV["VAGRANT_LOG"].nil? && ENV["VAGRANT_LOG"].upcase=='DEBUG'
            NIFTY::LOG.level = Logger::DEBUG
          end
          @connection = NIFTY::Cloud::Base.new(niftycloud_config)
        end

        # Create instance
        def create(options)
          server = @connection.run_instances(options).instancesSet.item.first
        end

        # Get instance information
        def get(machine)
          server = @connection.describe_instances(:instance_id => machine.id).reservationSet.item.first.instancesSet.item.first
        end

        # Start instance
        def start(env)
          env[:ui].info(I18n.t("vagrant_niftycloud.resuming"))

          # 起動直後等、resume処理できないステータスの場合一旦待つ
          server = get(env[:machine])
          while server.instanceState.name == 'pending'
            sleep 5
            server = get(env[:machine])
            env[:ui].info(I18n.t("vagrant_niftycloud.processing"))
          end

          if server.instanceState.name != 'running'
            @connection.start_instances(:instance_id => env[:machine].id)
            while server.instanceState.name != 'running'
              sleep 5
              server = get(env[:machine])
              env[:ui].info(I18n.t("vagrant_niftycloud.processing"))
            end
          end
        end

        # Stop instance
        def stop(env)
          env[:ui].info(I18n.t("vagrant_niftycloud.suspending"))

          # 起動直後等、stop処理できないステータスの場合一旦待つ
          server = get(env[:machine])
          while server.instanceState.name == 'pending'
            sleep 5
            server = get(env[:machine])
            env[:ui].info(I18n.t("vagrant_niftycloud.processing"))
          end

          if server.instanceState.name != 'stopped'
            @connection.stop_instances(:instance_id => env[:machine].id, :force => false)
            while server.instanceState.name != 'stopped'
              sleep 5
              server = get(env[:machine])
              env[:ui].info(I18n.t("vagrant_niftycloud.processing"))
            end
          end
        end

        # Terminate instance
        def delete(env)
          env[:ui].info(I18n.t("vagrant_niftycloud.terminating"))

          # 起動直後等、terminate処理できないステータスの場合一旦待つ
          server = get(env[:machine])
          while server.instanceState.name == 'pending'
            sleep 5
            server = get(env[:machine])
            env[:ui].info(I18n.t("vagrant_niftycloud.processing"))
          end

          attribute = @connection.describe_instance_attribute(:instance_id => env[:machine].id, :attribute => 'disableApiTermination')
          if attribute.disableApiTermination.value == 'false'
            # AWSのように即terminateができないため一旦stopする
            server = stop(env)
          end

          # terminate処理
          server = get(env[:machine])
          if server.instanceState.name == 'stopped'
            response = @connection.terminate_instances(:instance_id => env[:machine].id)
            return response
          end
        end
      end
    end
  end
end
