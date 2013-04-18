Capistrano::Configuration.instance.load do
  set :vycap_template_dir, File.expand_path("./vycap/templates/")
  set :vycap_partials_dir, vycap_template_dir + "/partials"
  set :vycap_user, nil
  set :vycap_remote_config, "/config/config.vycap"
  set :vycap_tmp_dir, "/tmp"
  set :vycap_template, "config"
  set :vycap_template_context, {}
  set :vycap_auth_dir, ""
  set :vycap_remote_auth_dir, "/config/auth/vycap/"

  namespace :vycap do
    task :download_config_template do
      failed_servers = roles[:vyatta].servers.map do |srv|
        remote_file = SupplyDrop::Rsync.remote_address(vycap_user, srv.host, "/config/config.boot")
        cmd = SupplyDrop::Rsync.command(
          remote_file,
          vycap_template_dir + "/config.#{srv}.erb",
          :ssh => ssh_options
        )
        srv unless system cmd
      end

      raise "rsync failed on #{failed_servers.inspect}" if failed_servers.any?

      roles[:vyatta].servers.map do |srv|
        config_template = vycap_template_dir + "/config.#{srv}.erb"

        original = File.read(config_template)
        File.open(config_template, "w") do |file|
          original.split("\n").each do |line|
            file.puts line unless line =~ /\bhw-id\b/
          end
        end
      end
    end

    namespace :upload do
      task :default do
        vycap.upload.config
        vycap.upload.auth_files unless vycap_auth_dir == ""
      end

      task :config do
        failed_servers = roles[:vyatta].servers.map do |srv|
          vycap_plugin.generate_config(srv, {
            :template => vycap_template,
            :template_dir => vycap_template_dir,
            :partials_dir => vycap_partials_dir,
            :output_dir => vycap_tmp_dir,
            :context => vycap_template_context
          })

          remote_file = SupplyDrop::Rsync.remote_address(vycap_user, srv.host, vycap_remote_config)

          cmd = SupplyDrop::Rsync.command(
            File.join(vycap_tmp_dir, "config.#{srv}"),
            remote_file,
            :ssh => ssh_options
          )
          srv unless system cmd
        end

        raise "rsync failed on #{failed_servers.inspect}" if failed_servers.any?

      end

      task :auth_files do
        set :user, vycap_user unless vycap_user.nil?
        failed_servers = roles[:vyatta].servers.map do |srv|
          remote_file = SupplyDrop::Rsync.remote_address(vycap_user, srv.host, vycap_remote_auth_dir)
          auth_dir = vycap_auth_dir

          remote_file += "/" unless remote_file =~ /\/$/
          auth_dir += "/" unless auth_dir =~ /\/$/


          cmd = SupplyDrop::Rsync.command(
            auth_dir,
            remote_file,
            :ssh => ssh_options
          )
          success = system cmd
          run("chmod 600 #{vycap_remote_auth_dir}/*")
          srv unless success
        end

        raise "rsync failed on #{failed_servers.inspect}" if failed_servers.any?
      end
    end

    namespace :diff do
      task :show do
        set :user, vycap_user unless vycap_user.nil?
        vycap_plugin.vrun(
          "begin",
          "load #{vycap_remote_config}",
          'show | grep -C 3 -E "^[+->]"',
          "discard",
          "end"
        )
      end

      task :apply do
        set :user, vycap_user unless vycap_user.nil?
        vycap_plugin.vrun(
          "begin",
          "load #{vycap_remote_config}",
          "commit",
          "save",
          "end"
        )
      end
    end
  end
end
