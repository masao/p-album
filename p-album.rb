#! /usr/local/bin/ruby
# $Id$

# index.html�ǡ��Ƕ� N ��ʬ��ɽ�����뤫
RECENT = 5

# ����͡�����֤��ǥ��쥯�ȥ�
THUMBS_DIR = "thumbs"

# HTML�ο����Τ���ǥ��쥯�ȥ�
TEMPLATE_DIR = 'templates'

# ����͡����������� convert ���ޥ�ɤΥ��ץ����
CONVERT_OPT = "-geometry '96x96>'"

# ��̾
MONTHNAMES = [nil] + %w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

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
      return @filename
   end

   def make_thumbnail
      system("convert #{CONVERT_OPT} #{filename} #{thumbname}") || raise("convert fails")
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

   # ʸ������ִ�
   def auto_replace (info)
      info.keys.each {|k|
	 if info[k].class == String
	    info[k].gsub!(/\[([^\]]+)\]/) {
	       match = $1
	       if match =~ /^(\d{4}-\d{2})-\d{2}$/ then
		  "<a href=\"#{$1}.html##{match}\">[#{match}]</a>"
	       elsif match =~ /^Cookpad:(\d+)$/i then
		  "<a href=\"http://cookpad.com/recipe.cfm?RID=#{$1}\">[#{match}]</a>"
	       else
		  "[#{match}]"
	       end
	    }
	 end
      }
   end

   def make_htmlpages
      @photos.each_index {|i|
	 puts @photos[i]
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
	 fileinfo['datetime'] = datetime.strftime("%Y-%m-%d %H:%M")
	 fileinfo['date'] = datetime.strftime("%Y-%m-%d")
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

	 template = TemplateFile.new("#{TEMPLATE_DIR}/htmlpage.html")
	 html = File.open(@photos[i].htmlname, "w")
	 html.print template.expand(fileinfo.update(@conf))
      }
   end

   def make_monthlypage
      daybody = Hash.new("")
      monthbody = Hash.new(0)
      @photos.each {|photo|
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
      }

      month = monthbody.keys.sort
      month.each_index{|i|
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
	    param['link_next'] = "<link rel=\"next\" href=\"#{month[i-1]}.html\" title=\"#{month[i+1]}\">"
	 end

	 template = TemplateFile.new("#{TEMPLATE_DIR}/monthlypage.html")
	 html = File.open("#{month[i]}.html", "w")
	 html.print template.expand(param.update(@conf))
      }

      # index.html �˺ǿ��ο���ʬ��񤭽Ф���
      param = Hash.new("")
      param["recent"] = RECENT
      days = daybody.keys.sort.reverse
      days[0 ... RECENT].each{|day|
	 param["body"] += "<div class=\"day-header\">#{day}</div>\n"
	 param["body"] += "<div class=\"day-body\">#{daybody[day]}</div>\n"
      }
      param["monthly_list"] = get_monthly_list(monthbody)
      monthbody.keys.sort.each {|m|
	 param["link_chapter"] += "<link rel=\"chapter\" href=\"#{m}.html\" title=\"#{m}\">\n"
      }
      param['now'] = Time.now.strftime "%Y-%m-%d %H:%M:%S"

      template = TemplateFile.new("#{TEMPLATE_DIR}/indexpage.html")
      html = File.open("index.html", "w")
      html.print template.expand(param.update(@conf))
   end

   def get_monthly_list (monthbody)
      result = ""
      prev_year = 0
      monthbody.keys.sort.each {|m|
	 year, month = m[0..3], m[5..6]
	 if year != prev_year then
	    # year changed!
	    result += "<br>\n" if prev_year != 0
	    result += "#{year} : \n"
	    prev_year = year
	 end
	 result += "<a href=\"#{m}.html\">#{MONTHNAMES[month.to_i]}</a>\n"
      }
      return result
   end

   def search (str)
      result = []
      @photos.each {|f|
	 f.info.keys.each {|key|
	    if f.info[key].class == String then
	       result.push f if f.info[key].downcase.index(str.downcase)
	    end
	 }
      }
      return result
   end
end