module Fastlane
  module Actions
    module SharedValues
      MOBILE_CENTER_DOWNLOAD_LINK = :MOBILE_CENTER_DOWNLOAD_LINK
      MOBILE_CENTER_BUILD_INFORMATION = :MOBILE_CENTER_BUILD_INFORMATION
    end

    class MobileCenterUploadAction < Action
      # create request
      def self.connection(upload_url = false)
        require 'faraday'
        require 'faraday_middleware'

        options = {
          url: upload_url ? upload_url : "https://api.mobile.azure.com"
        }

        Faraday.new(options) do |builder|
          if upload_url
            builder.request :multipart
            builder.request :url_encoded
          else
            builder.request :json
          end
          builder.response :json, content_type: /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      # creates new release upload and returns its upload_id and upload_url for app
      def self.create_release_upload(api_token, owner_name, app_name)
        connection = self.connection

        response = connection.post do |req|
          req.url("/v0.1/apps/#{owner_name}/#{app_name}/release_uploads")
          req.headers['X-API-Token'] = api_token
          req.body = {}
        end

        case response.status
        when 200...300
          if ENV['DEBUG_ACTION']
            UI.message("DEBUG: #{JSON.pretty_generate(response.body)}\n")
          end
          response.body
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        when 404
          UI.error("Not found, invalid owner or application name")
          false
        else
          UI.error("Error #{response.status}: #{response.body}")
          false
        end
      end

      # creates new dSYM upload, returns symbol_upload_id, upload_url, expiration_date
      def self.create_dsym_upload(api_token, owner_name, app_name)
        connection = self.connection

        response = connection.post do |req|
          req.url("/v0.1/apps/#{owner_name}/#{app_name}/symbol_uploads")
          req.headers['X-API-Token'] = api_token
          req.body = {
            symbol_type: 'Apple'
          }
        end

        case response.status
        when 200...300
          if ENV['DEBUG_ACTION']
            UI.message("DEBUG: #{JSON.pretty_generate(response.body)}\n")
          end
          response.body
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        when 404
          UI.error("Not found, invalid owner or application name")
          false
        else
          UI.error("Error #{response.status}: #{response.body}")
          false
        end
      end

      def self.upload_dsym(api_token, owner_name, app_name, dsym, symbol_upload_id, upload_url)
        connection = self.connection(upload_url)

        options = {}
      end

      # upload binary for specified upload_url
      # if succeed, then commits the release
      # otherwise aborts
      def self.upload(api_token, owner_name, app_name, file, upload_id, upload_url)
        connection = self.connection(upload_url)

        options = {}
        options[:upload_id] = upload_id
        # ipa field is used both for .apk and .ipa files
        options[:ipa] = Faraday::UploadIO.new(file, 'application/octet-stream') if file and File.exist?(file)

        response = connection.post do |req|
          req.body = options
        end

        case response.status
        when 200...300
          UI.message("Binary uploaded")
          self.update_release_upload(api_token, owner_name, app_name, upload_id, 'committed')
        else
          UI.error("Error uploading binary #{response.status}: #{response.body}")
          self.update_release_upload(api_token, owner_name, app_name, upload_id, 'aborted')
          UI.error("Release aborted")
          false
        end
      end

      # Commits or aborts the upload process for a release
      def self.update_release_upload(api_token, owner_name, app_name, upload_id, status)
        connection = self.connection

        response = connection.patch do |req|
          req.url("/v0.1/apps/#{owner_name}/#{app_name}/release_uploads/#{upload_id}")
          req.headers['X-API-Token'] = api_token
          req.body = {
            "status" => status
          }
        end

        case response.status
        when 200...300
          if ENV['DEBUG_ACTION']
            UI.message("DEBUG: #{JSON.pretty_generate(response.body)}\n")
          end
          response.body
        else
          UI.error("Error #{response.status}: #{response.body}")
          false
        end
      end

      # add release to distribution group
      def self.add_to_group(api_token, release_url, group_name, release_notes = '')
        connection = self.connection

        response = connection.patch do |req|
          req.url("/#{release_url}")
          req.headers['X-API-Token'] = api_token
          req.body = {
            "distribution_group_name" => group_name,
            "release_notes" => release_notes
          }
        end

        case response.status
        when 200...300
          release = response.body
          download_url = release['download_url']

          if ENV['DEBUG_ACTION']
            UI.message("DEBUG: #{JSON.pretty_generate(release)}")
          end

          Actions.lane_context[SharedValues::MOBILE_CENTER_DOWNLOAD_LINK] = download_url
          Actions.lane_context[SharedValues::MOBILE_CENTER_BUILD_INFORMATION] = release

          UI.message("Public Download URL: #{download_url}") if download_url
          UI.success("Release #{release['short_version']} was successfully distributed")

          release
        when 404
          UI.error("Not found, invalid distribution group name")
          false
        else
          UI.error("Error adding to group #{response.status}: #{response.body}")
          false
        end
      end

      def self.run(params)
        values = params.values
        api_token = params[:api_token]
        owner_name = params[:owner_name]
        app_name = params[:app_name]
        group = params[:group]
        file = params[:file]
        dsym = params[:dsym]

        if dsym and (File.extname(file) == '.ipa')
          dsym_path = dsym

          if File.directory?(dsym)
            UI.message("dSYM path is folder, zipping...")
            dsym_path = Actions::ZipAction.run(path: dsym, output_path: dsym + ".dSYM.zip")
            UI.message("dSYM files zipped")
          end

          UI.message("Starting dSYM upload...")
          dsym_upload_details = self.create_dsym_upload(api_token, owner_name, app_name)

          if dsym_upload_details
            symbol_upload_id = dsym_upload_details['symbol_upload_id']
            upload_url = dsym_upload_details['upload_url']

            UI.message("Uploading dSYM...")
            self.upload_dsym(api_token, owner_name, app_name, dsym_path, symbol_upload_id, upload_url)
          end
        end

        UI.message("Starting release upload...")
        upload_details = self.create_release_upload(api_token, owner_name, app_name)
        if upload_details
          upload_id = upload_details['upload_id']
          upload_url = upload_details['upload_url']

          UI.message("Uploading release binary...")
          uploaded = self.upload(api_token, owner_name, app_name, file, upload_id, upload_url)

          if uploaded
            release_url = uploaded['release_url']
            UI.message("Release committed")

            self.add_to_group(api_token, release_url, group, params[:release_notes])
            return values if Helper.test?
          end
        end
      end

      def self.description
        "Distribute new release to Mobile Center"
      end

      def self.authors
        ["evkhramkov"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :api_token,
                                  env_name: "MOBILE_CENTER_API_TOKEN",
                               description: "API Token for Mobile Center",
                                  optional: false,
                                      type: String,
                              verify_block: proc do |value|
                                UI.user_error!("No API token for Mobile Center given, pass using `api_token: 'token'`") unless value and !value.empty?
                              end),

          FastlaneCore::ConfigItem.new(key: :owner_name,
                                  env_name: "MOBILE_CENTER_OWNER_NAME",
                               description: "Owner name",
                                  optional: false,
                                      type: String,
                              verify_block: proc do |value|
                                UI.user_error!("No Owner name for Mobile Center given, pass using `owner_name: 'name'`") unless value and !value.empty?
                              end),

          FastlaneCore::ConfigItem.new(key: :app_name,
                                  env_name: "MOBILE_CENTER_APP_NAME",
                               description: "App name",
                                  optional: false,
                                      type: String,
                              verify_block: proc do |value|
                                UI.user_error!("No App name given, pass using `app_name: 'app name'`") unless value and !value.empty?
                              end),

          FastlaneCore::ConfigItem.new(key: :file,
                                  env_name: "MOBILE_CENTER_DISTRIBUTE_FILE",
                               description: "Build release path",
                                  optional: false,
                                      type: String,
                              verify_block: proc do |value|
                                UI.user_error!("Couldn't find build file at path '#{value}'") unless File.exist?(value)
                                accepted_formats = [".apk", ".ipa"]
                                UI.user_error!("Only \".apk\" and \".ipa\" formats are allowed, you provided \"#{File.extname(value)}\"") unless accepted_formats.include? File.extname(value)
                              end),

          FastlaneCore::ConfigItem.new(key: :dsym,
                                  env_name: "MOBILE_CENTER_DISTRIBUTE_DSYM",
                               description: "Path to your symbols file. For iOS and Mac provide path to app.dSYM.zip. For Android provide path to mappings.txt file",
                             default_value: Actions.lane_context[SharedValues::DSYM_OUTPUT_PATH],
                                  optional: true,
                                      type: String,
                              verify_block: proc do |value|
                                if value
                                  UI.user_error!("Couldn't find build file at path '#{value}'") unless File.exist?(value)
                                end
                              end),

          FastlaneCore::ConfigItem.new(key: :group,
                                  env_name: "MOBILE_CENTER_DISTRIBUTE_GROUP",
                               description: "Distribute group name",
                                  optional: false,
                                      type: String,
                              verify_block: proc do |value|
                                UI.user_error!("No Distribute Group given, pass using `group: 'group name'`") unless value and !value.empty?
                              end),

          FastlaneCore::ConfigItem.new(key: :release_notes,
                                  env_name: "MOBILE_CENTER_DISTRIBUTE_RELEASE_NOTES",
                               description: "Release notes",
                             default_value: Actions.lane_context[SharedValues::FL_CHANGELOG] || "No changelog given",
                                  optional: true,
                                      type: String)
        ]
      end

      def self.output
        [
          ['MOBILE_CENTER_DOWNLOAD_LINK', 'The newly generated download link for this build'],
          ['MOBILE_CENTER_BUILD_INFORMATION', 'contains all keys/values from the Mobile CEnter API']
        ]
      end

      def self.is_supported?(platform)
        true
      end

      def self.example_code
        [
          'mobile_center_upload(
            api_token: "...",
            owner_name: "mobile_center_owner",
            app_name: "testing_app",
            file: "./app-release.apk",
            group: "Testers",
            release_notes: ""
          )'
        ]
      end
    end
  end
end
