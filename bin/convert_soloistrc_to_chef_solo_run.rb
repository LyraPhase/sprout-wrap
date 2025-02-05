#!/usr/bin/env ruby
require 'erb'
require 'yaml'
require 'soloist/royal_crown'
require 'soloist/config'
require 'json'

## Monkey-patch Soloist::Config#run_chef() so it works with data bags
def run_chef
  exec(conditional_sudo("bash -c '#{chef_solo}'"))
end


royal_crown = Soloist::RoyalCrown.new(:path => 'soloistrc')
# For some reason, the init method does not actually initialize the object...
# we must reload it after path is set.
royal_crown =  royal_crown.reload
config = Soloist::Config.new( royal_crown )

### Soloist::Config methods:
### config.methods - Object.methods
###   => [:as_node_json, :as_solo_rb, :chef_cache_path, :chef_solo, :compiled, :cookbook_paths, :debug?, :log_level, :merge!, :node_json_path, :node_json_path=, :royal_crown, :solo_rb_path, :solo_rb_path=]
###

# Set Soloist Config Paths
config.solo_rb_path = '/tmp/chef-solo.rb'
config.node_json_path = '/tmp/node.json'

# Write out Chef Solo config
puts "Writing Persistent /tmp/chef-solo.rb from soloist config"
File.open('/tmp/chef-solo.rb', 'w') do |f|
  f.write(config.as_solo_rb)
end

# YAML
#yaml_text  = config.royal_crown.to_yaml
# Node JSON
File.open('/tmp/node.json', 'w') do |f|
  f.write(config.as_node_json.to_json)
end

puts "Soloist settings:"
puts "Log Level: #{config.log_level}"
puts "Cookbook Paths: #{config.cookbook_paths}"
puts "Chef Solo Run Command: #{config.chef_solo}"
puts "Temp Node JSON Path: #{config.node_json_path}"
puts "Temp chef-solo.rb Path: #{config.solo_rb_path}"
puts "Run List:"
puts config.compiled.recipes
puts ""
puts ""

puts "How to Run Standalone Chef Solo from persistent files generated by this script:"
puts ""
puts "rvm use system && sudo chef-solo -c '/tmp/chef-solo.rb' -l 'info' -W"
