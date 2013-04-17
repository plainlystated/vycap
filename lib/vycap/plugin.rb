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

      erb = File.read(template_filename)
      context = OpenStruct.new(options.fetch(:context, {}))
      File.open(output_filename, "w") do |out|
        out.write ERB.new(erb).result(context.eval { binding })
      end
    end
  end
end
