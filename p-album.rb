#! /usr/local/bin/ruby
# $Id$

require 'nkf'
require 'tempfile'
require 'ftools'
require 'image_size'
require 'yaml'

# ����͡�����֤��ǥ��쥯�ȥ�
THUMBS_DIR = "thumbs"

# ����͡����������� convert ���ޥ�ɤΥ��ץ����
CONVERT_OPT = "-geometry '96x96>' +profile '*'"

class String
	def shorten( len = 120 )
		lines = NKF::nkf( "-e -m0 -f#{len}", self.gsub( /<[^>]+>/, ' ' ).gsub( /\n/, ' ' ) ).split( /\n/ )
		lines[0].concat( '...' ) if lines[0] and lines[1]
		lines[0]
	end
end

class ImageSize
   def html_imgsize
      return "width=\"#{get_width}\" height=\"#{get_height}\""
   end
end

# �ʰץƥ�ץ졼�ȥ��饹
class TemplateFile
   def initialize (fname)
      @template = open(fname).read
   end
   def expand (param)
      return @template.gsub(/\$(\w+)/) {|s|
	 param[$1] if param.has_key?($1)
      }
   end
end

# �̿������ξ�������륯�饹
class PhotoFile
   attr_reader :filename, :thumbname, :htmlname, :info
   def initialize (fname, hash = {})
      base = File.basename(fname, ".jpg")
      @filename = fname
      @thumbname = "#{THUMBS_DIR}/#{fname}"
      @htmlname = "./#{base}.html"
      @info = hash
   end

   def to_s
      @filename
   end

   # ����͡����������Ԥ�
   def make_thumbnail
      system("convert #{CONVERT_OPT} #{filename} #{thumbname}") || raise("convert fails")
   end

   def size
      FileTest.size @filename
   end
end

# ʣ���β�������ʤ륢��Х��������륯�饹
class PhotoAlbum
   def initialize
      @metadata = YAML.load(open("metadata.yaml"))
      photofiles = @metadata.keys.select {|f|
	 f =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.jpg$/
      }
      @photos = photofiles.sort.collect {|f|
	 PhotoFile.new(f, @metadata[f])
      }
      @conf = {}
      if FileTest.readable?("p-album.conf") then
	 @conf = YAML::load(open("p-album.conf"))
      end
   end

   # ʸ�����ִ���Ԥ�
   ## FIXME:
   ## ��ĥ�����ʤ��Τǡ���ñ��¾�η���������Ǥ���褦�ˤ��롣
   ## e.g. Google:"foo", Amazon:"bar" ?
   def auto_replace (info)
      info.keys.each do |k|
	 if info[k].class == String
	    info[k].gsub!(/\[([^\]]+)\]/) {
	       match = $1
	       if match =~ /^(\d{4}-\d{2})-\d{2}$/ then
		  "<a href=\"./#{$1}.html##{match}\">[#{match}]</a>"
	       elsif match =~ /^(\d{4}-\d{2}-\d{2})[Tt ](\d{2}:\d{2}:\d{2})$/ then
		  "<a href=\"./#{$1}T#{$2}.html\">[#{match}]</a>"
	       elsif match =~ /^Cookpad:(\d+)$/i then
		  "<a href=\"http://cookpad.com/recipe.cfm?RID=#{$1}\">[#{match}]</a>"
	       else
		  "[#{match}]"
	       end
	    }
	 end
      end
   end

   # ʸ�����ե���������Ƥ���Ӥ��ơ��ѹ���������Τ߽񤭤���
   def write_to_file (str, fname)
      tempfile = Tempfile.new(fname)
      tempfile.print str
      tempfile.close
      unless File.exist?(fname) && File.cmp(fname, tempfile.path)
	 File.cp(tempfile.path, fname)
	 File.chmod(0644, fname)
	 puts fname
      end
   end

   # �̿����礴�Ȥ�HTML����Ϥ���
   def make_htmlpages
      @photos.each_index do |i|
	 # puts @photos[i]
	 fileinfo = Hash[@photos[i].info]
	 if fileinfo.has_key?("convert")
	    unless FileTest.exist?(@photos[i].filename + ".orig")
	       File.mv(@photos[i].filename, @photos[i].filename + ".orig")
	    end
	    unless FileTest.exist?(@photos[i].filename)
	       system("convert #{fileinfo["convert"]} #{@photos[i]}.orig #{@photos[i]}") || raise("convert fails")
	    end
	 end

	 if (FileTest.exist?(@photos[i].thumbname) == false ||
	     File.mtime(@photos[i].thumbname) < File.mtime(@photos[i].filename))
	    @photos[i].make_thumbnail
	 end

	 auto_replace(fileinfo)

	 datetime = fileinfo['datetime']
	 fileinfo['datetime'] = datetime.strftime("%Y-%m-%d %H:%M:%S")
	 fileinfo['date'] = datetime.strftime("%Y-%m-%d")
	 fileinfo['month'] = datetime.strftime("%Y-%m")
	 fileinfo['monthlyindex'] = datetime.strftime("%Y-%m.html")
	 fileinfo['image'] = "./#{@photos[i]}"
	 fileinfo['imagesize'] = ImageSize.new(open(@photos[i].filename)).html_imgsize
	 if i == 0 then
	    fileinfo['prev'] = "���μ̿�"
	 else
	    html = @photos[i-1].htmlname
	    fileinfo['prev'] = "<a href=\"#{html}\">���μ̿�</a>"
	    fileinfo['link_prev'] = "<link rel=\"prev\" href=\"#{html}\">"
	 end
	 if i == @photos.size - 1 then
	    fileinfo['next'] = "���μ̿�"
	 else
	    html = @photos[i+1].htmlname
	    fileinfo['next'] = "<a href=\"#{html}\">���μ̿�</a>"
	    fileinfo['link_next'] = "<link rel=\"next\" href=\"#{html}\">"
	 end

	 template = TemplateFile.new("#{@conf["TEMPLATE_DIR"]}/htmlpage.html")
	 write_to_file(template.expand(fileinfo.update(@conf)),
		       @photos[i].htmlname)
      end
   end

   # ���̤�HTML��index.html ����Ϥ���
   def make_monthlypage
      daybody = Hash.new("")
      monthbody = Hash.new(0)
      @photos.each do |photo|
	 datetime = photo.info["datetime"]
	 size = ImageSize.new(open(photo.thumbname)).html_imgsize
	 if photo.info.has_key?("title") then
	    alt_title = photo.info["title"]
	 else
	    alt_title = datetime.strftime "�ʻ������� %Y-%m-%d %H:%M��"
	 end

	 day = datetime.strftime "%Y-%m-%d"
	 month = datetime.strftime "%Y-%m"
	 daybody[day] += "<a href=\"#{photo.htmlname}\""
	 daybody[day] += " title=\"#{photo.info["title"]}\"" if photo.info.has_key?("title")
	 daybody[day] += "><img src=\"#{photo.thumbname}\" #{size} alt=\"#{alt_title}\"></a>\n"
	 monthbody[month] += 1
      end

      month = monthbody.keys.sort
      month.each_index do |i|
	 days = daybody.keys.sort.select {|e|
	    e =~ /^#{month[i]}/
	 }

	 param = Hash.new
	 param['total'] = monthbody[month[i]]
	 param['body'] = "<div class=\"monthbody\">\n"
	 days.each {|day|
	    param['body'] += "<div class=\"day-header\"><a name=\"#{day}\">#{day}</a></div>\n"
	    param['body'] += "<div class=\"day-body\">#{daybody[day]}</div>\n"
	 }
	 param['body'] += "</div>"
	 param['month'] = month[i]
	 if i == 0 then
	    param['prev'] = "����"
	 else
	    param['prev'] = "<a href=\"#{month[i-1]}.html\">����</a>"
	    param['link_prev'] = "<link rel=\"prev\" href=\"#{month[i-1]}.html\" title=\"#{month[i-1]}\">"
	 end
	 if i == month.size - 1 then
	    param['next'] = "���"
	 else
	    param['next'] = "<a href=\"#{month[i+1]}.html\">���</a>"
	    param['link_next'] = "<link rel=\"next\" href=\"#{month[i+1]}.html\" title=\"#{month[i+1]}\">"
	 end

	 template = TemplateFile.new("#{@conf["TEMPLATE_DIR"]}/monthlypage.html")
	 write_to_file(template.expand(param.update(@conf)),
		       "#{month[i]}.html")
      end

      # index.html �˺ǿ��ο���ʬ��񤭽Ф���
      param = Hash.new("")
      days = daybody.keys.sort.reverse
      days[0 ... @conf["RECENT"]].each do |day|
	 param["body"] += "<div class=\"day-header\">#{day}</div>\n"
	 param["body"] += "<div class=\"day-body\">#{daybody[day]}</div>\n"
      end
      param["monthly_list"] = get_monthly_list(monthbody)
      monthbody.keys.sort.each do |m|
	 param["link_chapter"] += "<link rel=\"chapter\" href=\"#{m}.html\" title=\"#{m}\">\n"
      end
      param['now'] = Time.now.strftime "%Y-%m-%d %H:%M:%S"
      param['total'] = @photos.size + 1
      param['total_size'] = total_size / 1024 / 1000

      template = TemplateFile.new("#{@conf["TEMPLATE_DIR"]}/indexpage.html")
      write_to_file(template.expand(param.update(@conf)), "index.html")
   end

   # ���̰�����HTML���֤�
   def get_monthly_list (monthbody)
      result = ""
      prev_year = 0
      month_list = monthbody.keys.sort
      start_year = month_list[0][0..3]
      end_year = month_list[month_list.size-1][0..3]
      (start_year .. end_year).each do |year|
	 result += "#{year} : \n"
	 ("01" .. "12").each do |month|
	    if monthbody.has_key?("#{year}-#{month}")
	       result += "<a href=\"#{year}-#{month}.html\">#{month}</a>\n"
	    else
	       result += "#{month}\n"
	    end
	 end
	 result += "<br>\n" if year != end_year
      end
      return result
   end

   # ������ɸ�����Ԥ�
   def search (str)
      result = @photos.select {|f|
	 stat = false
	 ["title", "description"].each do |key|
	    if (f.info[key].class == String &&
		f.info[key].downcase.index(str.downcase)) then
	       stat = true
	       break
	    end
	 end
	 stat
      }
      return result
   end

   # ��פΥ�����
   def total_size
      total = 0
      @photos.each do |f|
	 total += f.size
      end
      return total
   end
end
