# -*- coding: utf-8 -*-
require "log4r"
require 'vagrant/util/retryable'

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
          zone_config              = env[:machine].provider_config.get_zone_config(zone)
          instance_id              = zone_config.instance_id.nil? ? get_instance_id(5) : zone_config.instance_id
          image_id                 = zone_config.image_id
          zone                     = zone_config.zone
          instance_type            = zone_config.instance_type
          key_name                 = zone_config.key_name,
          firewall                 = zone_config.firewall,
          user_data                = zone_config.user_data,
          password                 = zone_config.password

          # Launch!
          env[:ui].info(I18n.t("vagrant_niftycloud.launching_instance"))
          env[:ui].info(" -- Server Type: #{instance_type}")
          env[:ui].info(" -- ImageId: #{image_id}")
          env[:ui].info(" -- Zone: #{zone}") if zone
          env[:ui].info(" -- Key Name: #{key_name}") if key_name
          env[:ui].info(" -- User Data: yes") if user_data
          env[:ui].info(" -- Firewall: #{firewall.inspect}") if !firewall.empty?

          options = {
            :instance_id              => instance_id,
            :availability_zone        => zone,
            :instance_type            => instance_type,
            :image_id                 => image_id,
            :key_name                 => zone_config.key_name,
            :user_data                => user_data,
            :base64_encoded           => true,
            :password                 => password,
            :accounting_type          => 2,    #従量課金
            :disable_api_termination  => false #APIから即terminate可
          }

          if !firewall.empty?
            options[:security_group] = firewall
          end

          # 例外の定義は以下参照
          # http://cloud.nifty.com/api/sdk/rdoc/
          begin
            # インスタンス立ち上げ開始
            server = env[:niftycloud_compute].create(options)
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

          # Immediately save the ID since it is created at this point.
          env[:machine].id = instance_id
            
          # リトライ回数。サーバステータスがrunningになるまで5秒のintervalでdescribe_instancesを実行するので
          # タイムアウト秒数/5を上限回数とする
          tries = zone_config.instance_ready_timeout / 5
          count = 0
          retryable(:on => Errors::InstanceReadyTimeout, :tries => tries) do
            env[:ui].info(I18n.t("vagrant_niftycloud.waiting_for_ready"))
            while server.instanceState.name != 'running'
              next if env[:interrupted]

              count += 1 
              sleep 5
              server = env[:niftycloud_compute].get(env[:machine])
              env[:ui].info(I18n.t("vagrant_niftycloud.processing"))
              if count > tries
                # Delete the instance
                terminate(env)
                # Notify the user
                raise Errors::InstanceReadyTimeout, timeout: zone_config.instance_ready_timeout
              end
            end
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

        def get_instance_id(length)
          instance_id = "vagrant"
          uid = (("a".."z").to_a + (0..9).to_a).shuffle[0..length].join
          instance_id << uid.capitalize
        end
      end
    end
  end
end
