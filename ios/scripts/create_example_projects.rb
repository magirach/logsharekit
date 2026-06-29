require "fileutils"
require "xcodeproj"

ROOT = File.expand_path("..", __dir__)

def configure_target(target, bundle_id)
  target.build_configurations.each do |config|
    config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_id
    config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "15.0"
    config.build_settings["SWIFT_VERSION"] = "5.10"
    config.build_settings["CODE_SIGNING_ALLOWED"] = "NO"
    config.build_settings["GENERATE_INFOPLIST_FILE"] = "YES"
    config.build_settings["INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents"] = "YES"
    config.build_settings["INFOPLIST_KEY_UILaunchScreen_Generation"] = "YES"
    config.build_settings["INFOPLIST_KEY_CFBundleDisplayName"] = bundle_id.split(".").last
    config.build_settings["ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS"] = "NO"
  end
end

def build_app_project(name:, bundle_id:, source_dir:)
  project_path = File.join(source_dir, "#{name}.xcodeproj")
  FileUtils.rm_rf(project_path)
  project = Xcodeproj::Project.new(project_path)
  target = project.new_target(:application, name, :ios, "15.0")
  configure_target(target, bundle_id)
  target.add_system_frameworks(["UIKit", "SwiftUI", "Foundation"])

  app_group = project.main_group.new_group("App", "App")
  Dir[File.join(source_dir, "App", "*.swift")].sort.each do |file|
    ref = app_group.new_file(file.sub("#{source_dir}/", ""))
    target.add_file_references([ref])
  end

  project.save
  project
end

def add_local_package_dependency(project_path:, target_name:, relative_package_path:, product_name:)
  project = Xcodeproj::Project.open(project_path)
  target = project.targets.find { |item| item.name == target_name }
  package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  package.relative_path = relative_package_path
  project.root_object.package_references << package

  product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product.package = package
  product.product_name = product_name
  target.package_product_dependencies << product

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product
  target.frameworks_build_phase.files << build_file

  dependency = project.new(Xcodeproj::Project::Object::PBXTargetDependency)
  dependency.product_ref = product
  target.dependencies << dependency

  project.save
end

spm_root = File.join(ROOT, "Examples", "SPMExample")
pods_root = File.join(ROOT, "Examples", "PodsExample")

build_app_project(
  name: "SPMExample",
  bundle_id: "com.example.logstreamer.spmexample",
  source_dir: spm_root
)

add_local_package_dependency(
  project_path: File.join(spm_root, "SPMExample.xcodeproj"),
  target_name: "SPMExample",
  relative_package_path: "../../",
  product_name: "LogStreamerKit"
)

build_app_project(
  name: "PodsExample",
  bundle_id: "com.example.logstreamer.podsexample",
  source_dir: pods_root
)
