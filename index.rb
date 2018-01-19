#!/usr/bin/ruby -rcgi -rerb

# Load modules
require 'base64'
require 'yaml'
require './gpgsym'
require 'fileutils'

# Definitions
Table={ :pass => 'Password', :host => 'Host/Group', :serv => 'Service', :user => 'Username', :loc  => 'Location', :uprq => 'Needs update?', :note => 'Notes' }

# Initialize
cgi=CGI.new
cgi.params.merge! CGI.parse(ENV['QUERY_STRING']||'')

# Utility functions
def cgi_out(b,status="OK")
	text=(ENV['REQUEST_METHOD']=='POST')
	b.eval('cgi').out(
		"status" => status,
		"type" => text ? "text/plain" : "text/html",
		"charset" => "utf-8"
	) { ERB.new(text ? b.eval('body') : IO.read('password.rhtml'),nil,nil,'_main_erb_out').result(b) }
	exit
end

def html_for_row(pk,row)
	ret=%Q(<tr id="#{pk}"><td class="sorthandle" style="text-align:center"><span style="margin:auto" class="ui-icon ui-icon-arrowthick-2-n-s"></span></td>)
	ret<<%Q(<td><span class="deletehandle ui-icon ui-icon-trash"></span></td>)
	Table.keys.each do |id|
		if id == :pass then
			icons = %Q(<span class="copyhandle ui-icon ui-icon-clipboard"></span><span class="showhandle ui-icon ui-icon-unlocked"></span>)
			klass = "hidden"
		else
			icons = ""
			klass = ""
		end
		ret<<%Q(<td><a href="#" id="v_#{id}_#{pk}" data-name="#{id}" data-pk="#{pk}" class="editable #{id} #{klass}">#{CGI.escapeHTML(row[id].to_s)}</a>#{icons}</td>)
	end
	ret<<'</tr>'
end

# Load password
password=nil
password=(Base64::decode64(ENV['HTTP_AUTHORIZATION'].split($;,2)[1]||'')||'').split(':',2)[1] unless
	ENV['AUTH_TYPE'].nil? or ENV['AUTH_TYPE']!='Basic' or ENV['HTTP_AUTHORIZATION'].nil?
if password.empty?
	body='Password parsing error.'
	cgi_out binding
end

# Read password file
safe_user=ENV['REMOTE_USER'].gsub(/[\/.]/,'')
data_path="data/#{safe_user}.yml.gpg"
begin
	f=File.open(data_path,"r+",0644)
	f.flock(File::LOCK_EX)
	encdata=f.read
rescue Errno::ENOENT
	encdata=nil
	mdata={}
rescue => e
	body='I/O error.'
	cgi_out binding
end
begin
	mdata=YAML.load(GPGSymmetric.decrypt(encdata,password)) || begin raise Exception end
rescue
	body='Parse or decrypt error.'
        cgi_out binding
end unless encdata.nil?

# Check operating mode
if ENV['REQUEST_METHOD']=='POST' then
	body=''
	# Add/Update/Move/Delete
	case cgi['a']
		when 'a'
			pk=(mdata[:sort].max||-1)+1

			mdata[pk]=Hash[Table.keys.map { |k| [k,cgi[k.to_s]] }]
			mdata[:sort]<<pk
			body=html_for_row(pk,mdata[pk])
		when 'u'
			pk=cgi['pk'].to_i
			unless mdata.include?(pk) and cgi.has_key?('pk')
				body='No such PK.'
				cgi_out binding,"NOT_FOUND"
			end
			name=cgi['name'].to_s.to_sym
			unless cgi.has_key?('name') and Table.keys.include?(name) and cgi.has_key?('value')
				body='Invalid parameters.'
				cgi_out binding,"BAD_REQUEST"
			end
			mdata[pk][name]=cgi['value']
		when 'm'
			pk=cgi['pk'].to_i
			unless mdata.include?(pk) and cgi.has_key?('pk')
				body='No such PK.'
				cgi_out binding,"NOT_FOUND"
			end
			after=(cgi['after']=='top') ? -1 : cgi['after'].to_i
			unless (after==-1 or mdata.include?(after)) and cgi.has_key?('after')
				body='No such insertion PK.'
				cgi_out binding,"NOT_FOUND"
			end			

			mdata[:sort].delete(pk)
			idx=(after==-1) ? -1 : mdata[:sort].find_index(after)
			mdata[:sort][idx+1,0]=pk
		when 'd'
			pk=cgi['pk'].to_i
			unless mdata.include?(pk) and cgi.has_key?('pk')
				body='No such PK.'
				cgi_out binding,"NOT_FOUND"
			end

			mdata.delete(pk)
			mdata[:sort].delete(pk)
		else
			body="No such action. <#{cgi['a']}>"
			cgi_out binding,"BAD_REQUEST"
	end
	# Save
	begin
		encdata=GPGSymmetric.encrypt(YAML.dump(mdata),password) || begin raise Exception end
		FileUtils.copy(data_path,data_path+".bak") if File.exists?(data_path)
		f.truncate(0)
		f.rewind
		f.write(encdata)
		f.close
	rescue
        	body='Encrypt error.'
	        cgi_out binding,"SERVER_ERROR"
	end
	cgi_out binding
else
	f.close
	# Generate manager table
	body=<<'END'
<form action="?a=a" method="post" id="addform">
<table>
<thead><tr><th></th><th></th>
<% Table.each do |id,name| %>
	<th id="h_<%=id%>"><%=name%></th>
<% end %>
</tr><tr><td style="width:25px"><div class="editableform-loading" style="display:none" id="addprogress"></div></td>
<td style="line-height:25px"><input type="submit" style="display:none" /><span id="addsubmit" onclick="$('#addform').submit()" class="ui-icon ui-icon-circle-plus"></span></td>
<% Table.keys.each do |id| %>
        <td><input name="<%=id%>"/></td>
<% end %>
</tr>
<tr id="adderror" class="ui-state-error" style="display:none"><td colspan="<%=Table.count+2%>"></td></tr>
</thead><tbody id="mtable">
<% mdata[:sort].each do |pk|; row=mdata[pk] %>
	<%=html_for_row(pk,row)%>
<% end %>
</tbody>
<tfoot><tr id="sortplaceholder" style="display:none"><td><div class="editableform-loading"></div></td><td colspan="<%=Table.count+1%>"></td></tr></tfoot>
</table>
</form>
END
	cgi_out binding
end

