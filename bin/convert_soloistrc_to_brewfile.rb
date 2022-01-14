#!/usr/bin/env ruby
require 'erb'
require 'yaml'

# Minimal ERB rendering class
# Reference: https://www.garethrees.co.uk/2014/01/12/create-a-template-rendering-class-with-erb/
# TODO: Handle options Hash https://github.com/Homebrew/homebrew-bundle/blob/master/lib/bundle/dsl.rb#L47
class SoloistrcToBrewfile < ERB
  def self.template
   brewfile_erb_template = <<-EOBREWFILE
  <% for @tap in @taps do %>tap '<%= @tap.split(' ').join("', '") %>'
  <% end  %>

  <% for  @formula in @formulas %>brew '<%= @formula %>'
  <% end  %>

  <% for  @cask in @casks %>cask '<%= @cask %>'
  <% end  %>
EOBREWFILE
  end

  def initialize(soloistrc_path = 'soloistrc', options = {trim_mode: '-'})
    @soloistrc = YAML.load(File.open(soloistrc_path))

    @taps     = @soloistrc['node_attributes']['homebrew']['taps']
    @casks    = @soloistrc['node_attributes']['homebrew']['casks']
    @formulas = @soloistrc['node_attributes']['homebrew']['formulas']

    @template = options.fetch(:template, self.class.template)
    super(@template)
  end

  def result
    super(binding)
  end
end


# Set Soloist Config Paths
brewfile_out_path = ENV['BREWFILE_PATH'] || '/tmp/Brewfile'
soloistrc_in_path = ENV['SOLOISTRC_PATH'] || 'soloistrc'
puts "BREWFILE_PATH=#{brewfile_out_path}"
puts "SOLOISTRC_PATH=#{soloistrc_in_path}"

# Extract & Convert Homebrew node_attribute data
brewfile = SoloistrcToBrewfile.new(soloistrc_in_path)
output = brewfile.result()

soloistrc = brewfile.instance_variable_get(:@soloistrc)

puts "Soloist ['node_attributes']['homebrew']:"
puts "==> Taps"
puts soloistrc['node_attributes']['homebrew']['taps']
puts ""
puts "==> Casks"
puts soloistrc['node_attributes']['homebrew']['casks']
puts ""
puts "==> Formulas"
puts soloistrc['node_attributes']['homebrew']['formulas']
puts ""

# Write out Brewfile
puts "Writing Brewfile from soloist config"
File.open(brewfile_out_path, 'w') do |f|
  f.write(output)
end

puts "How to Run Homebrew to install Brewfile items generated by this script:"
puts ""
puts "brew bundle install --file #{brewfile_out_path}"
