describe Fastlane do
  describe Fastlane::FastFile do
    describe "Mobile Center Integration" do
      before :each do
        allow(FastlaneCore::FastlaneFolder).to receive(:path).and_return(nil)
      end

      it "raises an error if no build file was given" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            mobile_center_upload({
              api_token: 'xxx',
              owner_name: 'owner',
              app_name: 'owner',
            })
          end").runner.execute(:test)
        end
      end
    end
  end
end
