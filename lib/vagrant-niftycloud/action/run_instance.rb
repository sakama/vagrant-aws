# -*- coding: utf-8 -*-
require "log4r"
require 'vagrant/util/retryable'
require 'vagrant-niftycloud/util/timer'

module VagrantPlugins
  module NiftyCloud
    module Action
      # This runs the configured instance.
      class RunInstance
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_niftycloud::action::run_instance")
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          # Get the zone we're going to booting up in
          zone = env[:machine].provider_config.zone

          # Get the configs
          # TODO 開発フェーズなのでinstance_idを固定にしている
          # Vagrantfileで設定できるようにすべきか、その場合Vagrantfileを共有している環境では同じIDでサーバ立てるとエラーになることを考慮する
          instance_id              = 'test2'
          zone_config              = env[:machine].provider_config.get_zone_config(zone)
          image_id                 = zone_config.image_id
          zone                     = zone_config.zone
          instance_type            = zone_config.instance_type
          key_name                 = zone_config.key_name,
          firewall                 = zone_config.firewall,
          user_data                = zone_config.user_data

          # Launch!
          env[:ui].info(I18n.t("vagrant_niftycloud.launching_instance"))
          env[:ui].info(" -- Server Type: #{instance_type}")
          env[:ui].info(" -- ImageId: #{image_id}")
          env[:ui].info(" -- Zone: #{zone}") if zone
          env[:ui].info(" -- Key Name: #{key_name}") if key_name
          env[:ui].info(" -- User Data: yes") if user_data
          env[:ui].info(" -- Firewall: #{firewall.inspect}") if !firewall.empty?
          env[:ui].info(" -- User Data: #{user_data}") if user_data

          options = {
            :instance_id              => instance_id,
            #:availability_zone       => zone,
            :instance_type            => instance_type,
            :image_id                 => image_id,
            :key_name                 => 'scubism',
            :password                 => 'password',
            :user_data                => user_data,
            :accounting_type          => 2, #従量課金
            :disable_api_termination  => false #APIから即terminate可
          }

          if !firewall.empty?
            options[:security_group] = firewall
          end

          # 例外の定義は以下参照
          # http://cloud.nifty.com/api/sdk/rdoc/
          begin
            NIFTY::LOG.level = Logger::DEBUG
            # インスタンス立ち上げ開始
            server = env[:niftycloud_compute].run_instances(options).instancesSet.item.first
          rescue NIFTY::ConfigurationError => e
            raise VagrantPlugins::NiftyCloud::Errors::NiftyCloudConfigurationError,
              :code    => e.error_code,
              :message => e.error_message
          rescue NIFTY::ArgumentError => e
            raise VagrantPlugins::NiftyCloud::Errors::NiftyCloudArgumentError,
              :code    => e.error_code,
              :message => e.error_message
          rescue NIFTY::ResponseError => e
            raise VagrantPlugins::NiftyCloud::Errors::NiftyCloudResponseError,
              :code    => e.error_code,
              :message => e.error_message
          end
            
          # Wait for the instance to be ready first
          env[:metrics]["instance_ready_time"] = Util::Timer.time do
            # リトライ回数。サーバステータスがrunningになるまで5秒のintervalでdescribe_instancesを実行するので
            # タイムアウト秒数/5を上限回数とする
            tries = zone_config.instance_ready_timeout / 5

            env[:ui].info(I18n.t("vagrant_niftycloud.waiting_for_ready"))
            count = 0
            while server.instanceState.name != 'running'
              count += 1 
              sleep 5
              server = env[:niftycloud_compute].describe_instances(:instance_id => instance_id).reservationSet.item.first.instancesSet.item.first
              if count > tries
                # Delete the instance
                terminate(env)
                # Notify the user
                raise Errors::InstanceReadyTimeout, timeout: zone_config.instance_ready_timeout
              end
            end
          end
          
          # Immediately save the ID since it is created at this point.
          env[:machine].id = instance_id

          @logger.info("Time to instance ready: #{env[:metrics]["instance_ready_time"]}")

          if !env[:interrupted]
            env[:metrics]["instance_ssh_time"] = Util::Timer.time do
              # Wait for SSH to be ready.
              env[:ui].info(I18n.t("vagrant_niftycloud.waiting_for_ssh"))
              while true
                # If we're interrupted then just back out
                break if env[:interrupted]
                #break if env[:machine].communicate.ready?
                sleep 2
              end
            end

            @logger.info("Time for SSH ready: #{env[:metrics]["instance_ssh_time"]}")

            # Ready and booted!
            env[:ui].info(I18n.t("vagrant_niftycloud.ready"))
          end

          # Terminate the instance if we were interrupted
          terminate(env) if env[:interrupted]

          @app.call(env)
        end

        def recover(env)
          return if env["vagrant.error"].is_a?(Vagrant::Errors::VagrantError)

          if env[:machine].provider.state.id != :not_created
            # Undo the import
            terminate(env)
          end
        end

        def terminate(env)
          destroy_env = env.dup
          destroy_env.delete(:interrupted)
          destroy_env[:config_validate] = false
          destroy_env[:force_confirm_destroy] = true
          env[:action_runner].run(Action.action_destroy, destroy_env)
        end
      end
    end
  end
end
