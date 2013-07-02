require "vagrant"

module VagrantPlugins
  module NiftyCloud
    module Errors
      class VagrantNiftyCloudError < Vagrant::Errors::VagrantError
        error_namespace("vagrant_niftycloud.errors")
      end

      class FogError < VagrantNiftyCloudError
        error_key(:fog_error)
      end

      class InstanceReadyTimeout < VagrantNiftyCloudError
        error_key(:instance_ready_timeout)
      end

      class RsyncError < VagrantNiftyCloudError
        error_key(:rsync_error)
      end
    end
  end
end
