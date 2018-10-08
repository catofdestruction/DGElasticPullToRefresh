Pod::Spec.new do |spec|
  spec.name         = "DGElasticPullView"
  spec.version      = "1.2"
  spec.authors      = { "Danil Gontovnik" => "gontovnik.danil@gmail.com" }
  spec.homepage     = "https://github.com/gontovnik/DGElasticPullToRefresh"
  spec.summary      = "Support pull to load more"
  spec.source       = { :git => "https://github.com/catofdestruction/DGElasticPullToRefresh.git", :tag => "#{spec.version}" }
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.platform     = :ios, '8.0'
  spec.source_files = "DGElasticPullToRefresh/*.swift"

  spec.requires_arc = true

  spec.ios.deployment_target = '8.0'
  spec.ios.frameworks = ['UIKit', 'Foundation']
end
