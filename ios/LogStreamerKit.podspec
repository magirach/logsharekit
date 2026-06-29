Pod::Spec.new do |spec|
  spec.name         = "LogStreamerKit"
  spec.version      = "0.1.0"
  spec.summary      = "On-demand mobile log streaming library for iOS."
  spec.description  = "LogStreamerKit captures app logs and URLSession network logs, prompts for consent, and uploads batched events to a backend."
  spec.homepage     = "https://example.com/logstreamerkit"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "OpenAI Codex" => "noreply@example.com" }
  spec.source       = { :git => "https://example.com/logstreamerkit.git", :tag => spec.version.to_s }
  spec.platform     = :ios, "15.0"
  spec.swift_version = "5.10"
  spec.source_files = "Sources/LogStreamerKit/**/*.swift"
  spec.frameworks   = "Foundation", "UIKit"
end
