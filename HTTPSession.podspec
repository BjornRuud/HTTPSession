Pod::Spec.new do |s|
  s.name         = "HTTPSession"
  s.version      = "0.5"
  s.summary      = "A minimalistic HTTP client written in Swift, based on URLSession."
  s.description  = <<-DESC
    - No unnecessary abstractions. Uses URLSession, URLRequest and HTTPURLResponse.
    - Progress tracking for both requests and responses.
    - Support for large files.
    - Minimalistic and single-purpose. The client should handle HTTP requests, responses and data transfer both ways. That's it.
  DESC
  s.homepage     = "https://github.com/BjornRuud/HTTPSession"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Bjørn Olav Ruud" => "mail@bjornruud.net" }
  s.social_media_url   = ""
  s.ios.deployment_target = "10.0"
  s.osx.deployment_target = "10.11"
  s.watchos.deployment_target = "3.0"
  s.tvos.deployment_target = "10.0"
  s.source       = { :git => ".git", :tag => s.version.to_s }
  s.source_files  = "Sources/**/*"
  s.frameworks  = "Foundation"
end
