#! /usr/local/bin/ruby -wT -Ke
# -*- Ruby -*-
# $Id$

require 'cgi'
require 'yaml'
require 'image_size'

$LOAD_PATH.unshift "."
require 'p-album.rb'

cgi = CGI.new
keyword = (cgi['keyword'][0] || "").strip
result = []
if keyword.length > 0 then
   album = PhotoAlbum.new
   result = album.search(keyword)
end

print cgi.header("text/html; charset=EUC-JP")

param = Hash.new("")
param["keyword"] = CGI.escapeHTML(keyword)
param["result"] = result.size
result.reverse.each {|f|
   title = f.info["title"] || "̵��"
   description = f.info["description"] || ""
   param["body"] += <<EOF
<tr>
 <td class="thumbnail">
  <a href="#{f.htmlname}" title="#{title}">
   <img src="#{f.thumbname}" #{ImageSize.new(open(f.thumbname)).html_imgsize}>
  </a>
 </td>
 <td valign="top">
 <dl>
  <dt>#{title}</dt>
  <dd>��������: <em>#{f.info["datetime"].strftime("%Y-%m-%d %H:%m:%S")}</em></dd>
  <dd>#{description}</dd>
 </dl>
 </td>
</tr>
EOF
}

conf = {}
if FileTest.readable?("p-album.conf") then
   conf = YAML.load(open("p-album.conf"))
end
template = TemplateFile.new("#{TEMPLATE_DIR}/search.html")
print template.expand(param.update(conf))
