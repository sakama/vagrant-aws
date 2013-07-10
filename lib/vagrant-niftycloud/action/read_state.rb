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
          instances = env[:niftycloud_compute].describe_instances(:instance_id => machine.id)
          if instances.nil?
            # The machine can't be found
            @logger.info("Machine not found or terminated, assuming it got destroyed.")
            machine.id = nil
            return :not_created
          end

          reservationSet.item.each do |set|
            set.instancesSet.item.each do |instance|
              server = instance.instancesSet.item.first
              if server.instanceId == machine.id
                state = server.instanceState.name
                case state
                when 'stopped', 'warning', 'waiting', 'creating', 'suspending', 'uploading', 'import_error', 'pending'
                  @logger.info("Machine not found or terminated, assuming it got destroyed.")
                  machine.id = nil
                  return :not_created
                else
                  return state.to_sym
                end
              end
            end
          end
          return :not_created
        end
      end
    end
  end
end
