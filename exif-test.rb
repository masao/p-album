#!/usr/local/bin/ruby
# $Id$

require 'exif'

def print_tag (exif, str)
  begin
    val = exif[str]
    print "#{str}\t#{val}"
    if val.tainted?
        puts "(tainted)"
    else 
	puts "(untainted)" 
    end
  rescue Exif::Error => e
    STDERR.print "#{str}\t(not found)\n"
  end
end

exif = Exif.new(ARGV[0])
p exif.ifd
exif.ifd = "0" # Exif::IFD::Zero
print_tag(exif, 'Make')
print_tag(exif, 'Model')
print_tag(exif, 'Software')
print_tag(exif, 'DateTime')
print_tag(exif, 'DateTimeOriginal')
