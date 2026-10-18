cask "hellomini" do
  version "0.8.0"
  sha256 "f4a11d1ed63fc945efe7cf7ffc942d1613dcf01979dd13e8bd440682be74219e"

  url "https://github.com/emmettl/hellomini/releases/download/v#{version}/Hello-Mini-#{version}-macos-arm64.zip"
  name "Hello Mini"
  desc "Macintosh-inspired desktop and desk accessories"
  homepage "https://hellomini.app/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Hello Mini.app"
end
