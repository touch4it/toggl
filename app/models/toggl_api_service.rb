require 'net/http'
require 'json'

# Responsible for fetching matching Toggl entries
class TogglAPIService

  def initialize(toggl_api_key, workspaces)
    @toggl_api_key = toggl_api_key
    @toggl_workspace = workspaces.split(',').map(&:strip) if workspaces.present?
  end

  def get_toggl_entries
    workspace_ids = []

    if @toggl_workspace.present?
      wid_response = get_workspaces_api_response()
      workspace_ids = wid_response.select{|k| @toggl_workspace.include?(k['name'])}.map{|k| k['id']}
    end

    # if user has setup workspace, use entries for those workspaces. If no workspace is setup, use all
    get_latest_toggl_entries_api_response().map { |entry|
      if entry["description"] =~ /\s*#(\d+)\s*/ && !entry["stop"].nil? && !entry["stop"].empty? &&
      (@toggl_workspace.blank? || workspace_ids.include?(entry['wid']))

        TogglAPIEntry.new(entry["id"],
                          $1.to_i,
                          Time.parse(entry["start"]),
                          entry["duration"].to_f / 3600,
                          entry["description"].gsub(/\s*#\d+\s*/, '')
                          )
      else
        nil
      end
    }.compact
  end

  def update_toggl_entry_tag(id)
    uri = URI.parse "https://api.track.toggl.com/api/v8/time_entries/#{id}"
    uri.query = URI.encode_www_form({ :user_agent => 'Redmine Toggl Client' })

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    req = Net::HTTP::Put.new(uri.request_uri, 'Content-Type' => 'application/json')
    req.basic_auth @toggl_api_key, 'api_token'
    req.body = {time_entry: {tags: ["synced"], tag_action: "add"}}.to_json

    http.request(req)
  end

protected

  def get_workspaces_api_response()
    uri = URI.parse "https://api.track.toggl.com/api/v8/workspaces"
    uri.query = URI.encode_www_form({ :user_agent => 'Redmine Toggl Client' })

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    req = Net::HTTP::Get.new(uri.request_uri)
    req.basic_auth @toggl_api_key, 'api_token'

    res = http.request(req)

    if res.code.eql? "200"
      JSON.parse(res.body)
    else
      []
    end
  end

  def get_latest_toggl_entries_api_response()
      uri = URI.parse "https://api.track.toggl.com/api/v8/time_entries"

      date = Date.new(Date.today.year, Date.today.month) << 1

      uri.query = URI.encode_www_form({
          :user_agent => 'Redmine Toggl Client',
          :start_date => date.strftime("%FT%T%:z")
      })

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      req = Net::HTTP::Get.new(uri.request_uri)
      req.basic_auth @toggl_api_key, 'api_token'

      res = http.request(req)

      if res.code.eql? "200"
        JSON.parse(res.body)
      else
        []
      end
    end

end
