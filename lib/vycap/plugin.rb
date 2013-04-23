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

      context.partials = evaluate_partials(options.fetch(:partials_dir), context)

      erb = File.read(template_filename)
      File.open(output_filename, "w") do |out|
        out.write ERB.new(erb).result(context.instance_eval { binding })
      end
    end

    def evaluate_partials(partials_dir, context)
      return @vycap_partials unless @vycap_partials.nil?

      @vycap_partials = {}

      Dir["#{partials_dir}/*.erb"].sort.each do |file|
        erb = File.read(file)

        @vycap_partials[File.basename(file, ".erb")] = ERB.new(erb).result(context.instance_eval { binding })
      end

      @vycap_partials
    end

    def vcmd(cmd)
      "/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper #{cmd}"
    end

    def vrun(*cmds)
      cmds = cmds.flatten
      if cmds.last.is_a?(Hash)
        options = cmds.pop
      else
        options = {}
      end

      vcmds = cmds.map do |cmd|
        vcmd(cmd)
      end

      sudo_prefix = options.fetch(:sudo, false) ? sudo : ""

      run %Q{#{sudo_prefix} vbash -c '#{vcmds.join(" && ")}'; true}, :eof => true, :shell => false do |ch, stream, data|
        case stream
        when :out
          if data =~ /^enter .* password:$/i
            password = Capistrano::CLI.password_prompt(data + " ")
            ch.send_data(password + "\n")
          elsif data =~ /is not valid/ || data =~ /failed/
            puts _colorize(data, "\033[31m")
          else
            puts data
          end
        when :err then warn "[err :: #{ch[:server]}] #{data}"
        end
      end
    end

    def vsudo(*cmds)
      vrun cmds, :sudo => true
    end

    # borrowed from http://www.codedrop.ca/blog/archives/200
    def _colorize(text, color_code)
      "#{color_code}#{text}\033[0m"
    end
  end
end
