g = Gem::Specification.new do |s|
  s.name        = 'vycap'
  s.version     = '1.1.0'
  s.date        = Time.now.strftime("%Y-%m-%d")
  s.summary     = "Capistrano support for managing Vyatta"
  s.description = "Tested on Vyatta 6.5"
  s.authors     = ["Patrick Schless"]
  s.email       = 'patrick@plainlystated.com'
  s.files       = Dir[File.dirname(__FILE__) + "/lib/**/*.rb"]
  s.homepage    = 'https://github.com/plainlystated/vycap'
end
