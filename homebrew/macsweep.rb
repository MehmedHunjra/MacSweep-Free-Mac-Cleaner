cask "macsweep" do
  version "3.3"
  sha256 "8826c5b63fb3537b462691eda7d873486b246e0148e4b918294194220f149417"

  url "https://github.com/MehmedHunjra/MacSweep/releases/download/v#{version}/MacSweep-Installer-v#{version}.dmg"
  name "MacSweep"
  desc "Free open source Mac cleaner, optimizer and security tool"
  homepage "https://github.com/MehmedHunjra/MacSweep"

  app "MacSweep.app"

  zap trash: [
    "~/Library/Application Support/MacSweep",
    "~/Library/Caches/com.besttech.MacSweep",
    "~/Library/Preferences/com.besttech.MacSweep.plist",
  ]
end
