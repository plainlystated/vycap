require 'erb'
require 'ostruct'

module Vycap
  module Plugin
    def generate_config(server, options)
      template_filename = File.join(
        options.fetch(:template_dir),
        options.fetch(:template)
      )
      output_filename = File.join(
        options.fetch(:output_dir),
        "config.#{server}"
      )
      template_filename += ".erb" unless template_filename =~ /\.erb$/

      context = if options[:context].nil?
                  OpenStruct.new
                elsif options[:context].respond_to?(:call)
                  OpenStruct.new(options[:context].call(server))
                else
                  OpenStruct.new(options[:context])
                end

      erb = File.read(template_filename)
      File.open(output_filename, "w") do |out|
        out.write ERB.new(erb).result(context.instance_eval { binding })
      end
    end

    def vcmd(cmd)
      "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper #{cmd}"
    end

    def vrun(*cmds)
      cmds = cmds.flatten

      vcmds = cmds.map do |cmd|
        vcmd(cmd)
      end

      run %Q{#{vcmds.join(" && ")}}, :shell => "vbash", :eof => true do |ch, stream, data|
        case stream
        when :out
          if data =~ /is not valid/ || data =~ /failed/
            puts _colorize(data, "\033[31m")
          else
            puts data
          end
        when :err then warn "[err :: #{ch[:server]}] #{data}"
        end
      end
    end

    def vsudo(*cmds)
      sudo_cmds = cmds.flatten.map {|cmd| "#{sudo} #{cmd}"}
      vrun sudo_cmds
    end

    # borrowed from http://www.codedrop.ca/blog/archives/200
    def _colorize(text, color_code)
      "#{color_code}#{text}\033[0m"
    end
  end
end
