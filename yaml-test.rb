#! /usr/local/bin/ruby
# $Id$

require 'time'
require 'exif'
require 'yaml'

def exif2hash (exif)
  hash = Hash.new
  exif.each_entry() {|tag, value|
    hash[tag] = value
  }
  return hash
end

metadata = YAML::load(File.open "metadata.yaml")

exif = Exif.new(ARGV[0])
hash = exif2hash(exif)
puts( { File::basename(ARGV[0]) => { "EXIF info" => hash } }.to_yaml )

puts( {"datetime" => Time.new}.to_yaml)

yaml = YAML::Store.new("metadata.yaml", {})
yaml.transaction do 
  yaml['names'] = ['Steve', 'Jonathan', 'Tom'] 
  yaml['hello'] = {'hi' => 'hello', 'yes' => 'YES!!' } 
end 
