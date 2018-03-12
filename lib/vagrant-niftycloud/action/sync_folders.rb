# -*- coding: utf-8 -*-
require "log4r"

require "vagrant/util/subprocess"

module VagrantPlugins
  module NiftyCloud
    module Action
      # This middleware uses `rsync` to sync the folders over to the
      # NiftyCloud instance.
      class SyncFolders
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_niftycloud::action::sync_folders")
        end

        def call(env)
          @app.call(env)

          ssh_info = env[:machine].ssh_info
          env[:machine].config.vm.synced_folders.each do |id, data|
            begin
              # Ignore disabled shared folders
              next if data[:disabled]

              hostpath  = File.expand_path(data[:hostpath], env[:root_path])
              guestpath = data[:guestpath]

              private_key_paths = ssh_info[:private_key_path]
              private_key_path = private_key_paths[0]
              if Vagrant::Util::Platform.windows? && ENV['PATH'].include?("cygwin")
                hostpath  = hostpath.gsub(/\A(\w):/,'/cygdrive/\1')
                private_key_path = private_key_path.gsub(/\A(\w):/,'/cygdrive/\1')
              end

              # Make sure there is a trailing slash on the host path to
              # avoid creating an additional directory with rsync
              hostpath = "#{hostpath}/" if hostpath !~ /\/$/

              env[:ui].info(I18n.t("vagrant_niftycloud.rsync_folder",
                                  :hostpath => hostpath,
                                  :guestpath => guestpath))

              # Create the guest path
              env[:machine].communicate.sudo("mkdir -p '#{guestpath}'")
              env[:machine].communicate.sudo(
                "chown #{ssh_info[:username]} '#{guestpath}'")

              # Rsync over to the guest path using the SSH info
              command = [
                "rsync", "--verbose", "--archive", "-z",
                "--exclude", ".vagrant/", "--exclude", ".git/",
                "-e", "ssh -p #{ssh_info[:port]} -o StrictHostKeyChecking=no -i '#{private_key_path}'",
                hostpath,
                "#{ssh_info[:username]}@#{ssh_info[:host]}:#{guestpath}"]

              r = Vagrant::Util::Subprocess.execute(*command)
              if r.exit_code != 0
                raise Errors::RsyncError,
                  :guestpath => guestpath,
                  :hostpath => hostpath,
                  :stderr => r.stderr
              end
            rescue => e
              raise Errors::RsyncError,
                :guestpath => guestpath,
                :hostpath => hostpath,
                :stderr => e.message
            end
          end
        end
      end
    end
  end
end
