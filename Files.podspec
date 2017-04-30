Pod::Spec.new do |s|
  s.name         = "Files"
  s.version      = "1.8.0"
  s.summary      = "A nicer way to handle files & folders in Swift"
  s.description  = <<-DESC
    Files is a compact library that provides a nicer way to handle files and folders in Swift. It’s primarily aimed at Swift scripting and tooling, but can also be embedded in applications that need to access the file system. It's essentially a thin wrapper around the FileManager APIs that Foundation provides.
  DESC
  s.homepage     = "https://github.com/johnsundell/files"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "John Sundell" => "john@sundell.co" }
  s.social_media_url   = "https://twitter.com/johnsundell"
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"
  s.tvos.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/johnsundell/files.git", :tag => s.version.to_s }
  s.source_files  = "Sources/**/*"
  s.frameworks  = "Foundation"
end
