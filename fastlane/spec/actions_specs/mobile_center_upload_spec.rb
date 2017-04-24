def stub_create_release_upload(status)
  stub_request(:post, "https://api.mobile.azure.com/v0.1/apps/owner/app/release_uploads")
    .with(
      body: "{}",
      headers: {
        'Accept' => '*/*',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Content-Type' => 'application/json',
        'User-Agent' => 'Faraday v0.12.0.1',
        'X-Api-Token' => 'xxx'
      }
    )
    .to_return(
      status: status,
      body: "{\"upload_id\":\"upload_id\",\"upload_url\":\"https://upload.com\"}",
      headers: { 'Content-Type' => 'application/json' }
    )
end

def stub_upload(status)
  stub_request(:post, "https://upload.com/")
    .to_return(status: status, body: "", headers: {})
end

def stub_update_release_upload(status, release_status)
  stub_request(:patch, "https://api.mobile.azure.com/v0.1/apps/owner/app/release_uploads/upload_id")
    .with(
      body: "{\"status\":\"#{release_status}\"}",
      headers: {
        'Accept' => '*/*',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Content-Type' => 'application/json', 'User-Agent' => 'Faraday v0.12.0.1',
        'X-Api-Token' => 'xxx'
      }
    )
    .to_return(status: status, body: "{\"release_url\":\"v0.1/apps/owner/app/releases/1\"}", headers: {})
end

def stub_add_to_group(status)
  stub_request(:patch, "https://api.mobile.azure.com/release_url")
    .to_return(status: status, body: "{\"short_version\":\"1.0\",\"download_link\":\"https://download.link\"}", headers: { 'Content-Type' => 'application/json' })
end

describe Fastlane do
  describe Fastlane::FastFile do
    describe "Mobile Center Integration" do
      before :each do
        allow(FastlaneCore::FastlaneFolder).to receive(:path).and_return(nil)
      end

      it "raises an error if no api token was given" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              owner_name: 'owner',
              app_name: 'app',
              group: 'Testers',
              file: './fastlane/spec/fixtures/appfiles/apk_file_empty.apk'
            })
          end").runner.execute(:test)
        end.to raise_error("No API token for Mobile Center given, pass using `api_token: 'token'`")
      end

      it "raises an error if no owner name was given" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              app_name: 'app',
              group: 'Testers',
              file: './fastlane/spec/fixtures/appfiles/apk_file_empty.apk'
            })
          end").runner.execute(:test)
        end.to raise_error("No Owner name for Mobile Center given, pass using `owner_name: 'name'`")
      end

      it "raises an error if no app name was given" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              owner_name: 'owner',
              group: 'Testers',
              file: './fastlane/spec/fixtures/appfiles/apk_file_empty.apk'
            })
          end").runner.execute(:test)
        end.to raise_error("No App name given, pass using `app_name: 'app name'`")
      end

      it "raises an error if no group was given" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              owner_name: 'owner',
              app_name: 'app',
              file: './fastlane/spec/fixtures/appfiles/apk_file_empty.apk'
            })
          end").runner.execute(:test)
        end.to raise_error("No Distribute Group given, pass using `group: 'group name'`")
      end

      it "raises an error if no build file was given" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              owner_name: 'owner',
              app_name: 'app',
              group: 'Testers'
            })
          end").runner.execute(:test)
        end.to raise_error("Couldn't find build file at path ''")
      end

      it "raises an error if given file was not found" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              owner_name: 'owner',
              app_name: 'app',
              group: 'Testers',
              file: './nothing.apk'
            })
          end").runner.execute(:test)
        end.to raise_error("Couldn't find build file at path './nothing.apk'")
      end

      it "raises an error if given file has invalid extension" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              owner_name: 'owner',
              app_name: 'app',
              group: 'Testers',
              file: './fastlane/spec/fixtures/appfiles/Appfile_empty'
            })
          end").runner.execute(:test)
        end.to raise_error("Only \".apk\" and \".ipa\" formats are allowed, you provided \"\"")
      end

      it "works with valid parameters for android" do
        stub_create_release_upload(200)
        stub_upload(200)
        stub_update_release_upload(200, 'committed')
        stub_add_to_group(200)

        Fastlane::FastFile.new.parse("lane :test do
          mobile_center_upload({
            api_token: 'xxx',
            owner_name: 'owner',
            app_name: 'app',
            file: './fastlane/spec/fixtures/appfiles/apk_file_empty.apk',
            group: 'Testers'
          })
        end").runner.execute(:test)
      end

      it "works with valid parameters for ios" do
        stub_create_release_upload(200)
        stub_upload(200)
        stub_update_release_upload(200, 'committed')
        stub_add_to_group(200)

        Fastlane::FastFile.new.parse("lane :test do
          mobile_center_upload({
            api_token: 'xxx',
            owner_name: 'owner',
            app_name: 'app',
            file: './fastlane/spec/fixtures/appfiles/ipa_file_empty.ipa',
            group: 'Testers'
          })
        end").runner.execute(:test)
      end

      it "handles invalid token error" do
        expect do
          stub_create_release_upload(401)

          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              owner_name: 'owner',
              app_name: 'app',
              file: './fastlane/spec/fixtures/appfiles/apk_file_empty.apk',
              group: 'Testers'
            })
          end").runner.execute(:test)
        end.to raise_error("Auth Error, provided invalid token")
      end

      it "handles upload error" do
        stub_create_release_upload(200)
        stub_upload(400)
        stub_update_release_upload(200, 'aborted')

        Fastlane::FastFile.new.parse("lane :test do
          mobile_center_upload({
            api_token: 'xxx',
            owner_name: 'owner',
            app_name: 'app',
            file: './fastlane/spec/fixtures/appfiles/apk_file_empty.apk',
            group: 'Testers'
          })
        end").runner.execute(:test)
      end

      it "handles not found owner or app error" do
        stub_create_release_upload(404)

        Fastlane::FastFile.new.parse("lane :test do
          mobile_center_upload({
            api_token: 'xxx',
            owner_name: 'owner',
            app_name: 'app',
            file: './fastlane/spec/fixtures/appfiles/apk_file_empty.apk',
            group: 'Testers'
          })
        end").runner.execute(:test)
      end

      it "handles not found distribution group" do
        stub_create_release_upload(200)
        stub_upload(200)
        stub_update_release_upload(200, 'committed')
        stub_add_to_group(404)

        Fastlane::FastFile.new.parse("lane :test do
          mobile_center_upload({
            api_token: 'xxx',
            owner_name: 'owner',
            app_name: 'app',
            file: './fastlane/spec/fixtures/appfiles/apk_file_empty.apk',
            group: 'Testers'
          })
        end").runner.execute(:test)
      end

      it "can use a generated changelog as release notes" do
        stub_create_release_upload(200)
        stub_upload(200)
        stub_update_release_upload(200, 'committed')
        stub_add_to_group(200)

        values = Fastlane::FastFile.new.parse("lane :test do
          Actions.lane_context[SharedValues::FL_CHANGELOG] = 'autogenerated changelog'

          mobile_center_upload({
            api_token: 'xxx',
            owner_name: 'owner',
            app_name: 'app',
            file: './fastlane/spec/fixtures/appfiles/apk_file_empty.apk',
            group: 'Testers'
          })
        end").runner.execute(:test)

        expect(values[:release_notes]).to eq('autogenerated changelog')
      end
    end
  end
end
