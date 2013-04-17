require 'supply_drop'
require File.expand_path(File.dirname(__FILE__) + "/vycap/tasks")
require File.expand_path(File.dirname(__FILE__) + "/vycap/plugin")

Capistrano.plugin :vycap_plugin, Vycap::Plugin
