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
          begin
            env[:ui].info(I18n.t("vagrant_niftycloud.terminating"))

            attribute = env[:niftycloud_compute].describe_instance_attribute(:instance_id => env[:machine].id, :attribute => 'disableApiTermination')
            if attribute.disableApiTermination.value != 'false'
              # API経由で立ち上げていない場合、即terminateができないため念のため一旦stopする
              server = env[:niftycloud_compute].describe_instances(:instance_id => env[:machine].id).reservationSet.item.first.instancesSet.item.first
              if server.instanceState.name != 'stopped'
                env[:niftycloud_compute].stop_instances(:instance_id => env[:machine].id, :force => true)
                while server.instanceState.name != 'stopped'
                  server = env[:niftycloud_compute].describe_instances(:instance_id => env[:machine].id).reservationSet.item.first.instancesSet.item.first
                  sleep 5
                end
              end

              if config[:force] == false
                # TODO APIからの削除拒否の場合。考慮する必要はあるか
              else
                env[:niftycloud_compute].modify_instance_attribute(:instance_id => env[:machine].id, :attribute => 'disableApiTermination', :value => 'false')
                while attribute.disableApiTermination.value != 'false'
                  attribute = env[:niftycloud_compute].describe_instance_attribute(:instance_id => env[:machine].id, :attribute => 'disableApiTermination')
                  sleep 5
                end
              end
            end

            #terminate処理
            response = env[:niftycloud_compute].terminate_instances(:instance_id => env[:machine].id)
            env[:machine].id = nil

            @app.call(env)
          rescue NoMethodError
            ui.error("Could not locate server '#{env[:machine].id}'.  Please verify it was provisioned in the current zone.")	
          end
        end
      end
    end
  end
end
