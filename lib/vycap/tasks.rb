Capistrano::Configuration.instance.load do
  set :vycap_template_dir, File.expand_path("./vycap/templates/")
  set :vycap_user, "vyatta"
  set :vycap_remote_config, "/config/config.vycap"
  set :vycap_tmp_dir, "/tmp"
  set :vycap_template, "config"

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

    task :upload_config do
      failed_servers = roles[:vyatta].servers.map do |srv|
        vycap_plugin.generate_config(srv, {
          :template => vycap_template,
          :template_dir => vycap_template_dir,
          :output_dir => vycap_tmp_dir
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
  end
end
