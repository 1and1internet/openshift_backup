#!/usr/bin/env ruby

require 'sinatra'
require 'json'

set :bind, '0.0.0.0'
set :port, '8080'

get '/health' do
  '<html><body>OK</body></html>'
end

get '/' do
  cache_file = '/dev/shm/status_cache'
  if !File.exist?(cache_file) || (File.mtime(cache_file) < (Time.now - 60*15)) # cache result for 15 minutes
    data = `/backup_script.rb status`
    File.open(cache_file,"w"){ |f| f << data }
  end
  "<html><body>#{File.read(cache_file)}</body></html>"
end

get '/off_cluster_backup_status' do
  content_type :json
  
  collection_status_raw = `/off-cluster-backup.sh collection-status`  
  collection_status_raw.each_line do |line|
    if line.include? "Last full backup date"
      # line="Last full backup date: Wed Jan  9 12:27:39 2019"
      _, date_string = line.split("Last full backup date:")
      
      if date_string.nil?
        return create_json_response(message: "Could not find 'Last full backup date' - got #{line}")
      end
      
      if date_string.strip == "none"
        return create_json_response(message: "Last full backup date is 'none'")
      end
      
      last_backup_date = Date.parse(date_string)
      if !last_backup_date
        return create_json_response(message: "Could not parse 'Last full backup date' - got #{date_string}")
      end

      # if last backup date is over 24 hours old
      if DateTime.now - (1.0) > last_backup_date
        return create_json_response(message: "Last full backup date was #{date_string} which is more than 24 hours old")
      end

      return create_json_response(status: "OK", message: "Off cluster backup is OK, Last backup date #{date_string}")     
    end
  end 
  return create_json_response(status: "KO", message: "Could not check date of last off cluster backup - error: #{collection_status_raw}")
end

def create_json_response(status: "KO", message: "")
  return {
    "status" => status,
    "message" => message,
  }.to_json
end