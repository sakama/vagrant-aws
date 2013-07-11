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

          # Get the region we're going to booting up in
          region = env[:machine].provider_config.region

          # Get the configs
          region_config            = env[:machine].provider_config.get_region_config(region)
          image_id                 = region_config.image_id
          availability_zone        = region_config.availability_zone
          instance_type            = region_config.instance_type
          key_name                 = region_config.key_name,
          security_groups          = [region_config.security_groups]
          user_data                = region_config.user_data

          # Launch!
          env[:ui].info(I18n.t("vagrant_niftycloud.launching_instance"))
          env[:ui].info(" -- Type: #{instance_type}")
          env[:ui].info(" -- ImageId: #{image_id}")
          env[:ui].info(" -- Availability Zone: #{availability_zone}") if availability_zone
          env[:ui].info(" -- Key Name: #{key_name}") if key_name
          env[:ui].info(" -- User Data: yes") if user_data
          env[:ui].info(" -- Security Groups: #{security_groups.inspect}") if !security_groups.empty?
          env[:ui].info(" -- User Data: #{user_data}") if user_data

          begin
            options = {
              :availability_zone        => availability_zone,
              :instance_type            => instance_type,
              :image_id                 => image_id,
              :key_name                 => key_name,
              :user_data                => user_data
              :accounting_type          => 2 #従量課金
              :disable_api_termination  => false #APIから即terminate可
            }

            if !security_groups.empty?
              security_group_key = :groups
              options[security_group_key] = security_groups
            end

            # インスタンス立ち上げ開始
            server = env[:niftycloud_compute].run_instances(options).instancesSet.item.first

            # wait for it to be ready to do stuff
            while server.instanceState.name != 'running'
              server = env[:niftycloud_compute].describe_instances(:instance_id => server.instanceId).reservationSet.item.first.instancesSet.item.first
              sleep 5
            end
          rescue
            raise Errors::VagrantNiftyCloudError, :message => e.message
          end

          # Immediately save the ID since it is created at this point.
          env[:machine].id = server.instanceId
          
          # Wait for the instance to be ready first
          env[:metrics]["instance_ready_time"] = Util::Timer.time do
            tries = region_config.instance_ready_timeout / 2

            env[:ui].info(I18n.t("vagrant_niftycloud.waiting_for_ready"))
            begin
              retryable(:on => Fog::Errors::TimeoutError, :tries => tries) do
                # If we're interrupted don't worry about waiting
                next if env[:interrupted]

                # Wait for the server to be ready
                server.wait_for(2) { ready? }
              end
            rescue
              # Delete the instance
              terminate(env)

              # Notify the user
              raise Errors::InstanceReadyTimeout, timeout: region_config.instance_ready_timeout
            end
          end

          @logger.info("Time to instance ready: #{env[:metrics]["instance_ready_time"]}")

          if !env[:interrupted]
            env[:metrics]["instance_ssh_time"] = Util::Timer.time do
              # Wait for SSH to be ready.
              env[:ui].info(I18n.t("vagrant_niftycloud.waiting_for_ssh"))
              while true
                # If we're interrupted then just back out
                break if env[:interrupted]
                break if env[:machine].communicate.ready?
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
