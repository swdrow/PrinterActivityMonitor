#!/usr/bin/env ruby
# Script to add PrinterActivityMonitorTests target to the Xcode project
# Requires xcodeproj gem: gem install xcodeproj

begin
  require 'xcodeproj'
rescue LoadError
  puts "Error: xcodeproj gem not found"
  puts "Please install it with: gem install xcodeproj"
  exit 1
end

project_path = 'PrinterActivityMonitor.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
main_target = project.targets.find { |t| t.name == 'PrinterActivityMonitor' }

unless main_target
  puts "Error: Could not find PrinterActivityMonitor target"
  exit 1
end

# Check if test target already exists
test_target = project.targets.find { |t| t.name == 'PrinterActivityMonitorTests' }

if test_target
  puts "Test target already exists!"
else
  # Create test target
  test_target = project.new_target(:unit_test_bundle, 'PrinterActivityMonitorTests', :ios, '17.0')
  test_target.product_name = 'PrinterActivityMonitorTests'

  # Add TEST_HOST build setting
  test_target.build_configurations.each do |config|
    config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/PrinterActivityMonitor.app/$(BUNDLE_EXECUTABLE_PATH)'
    config.build_settings['INFOPLIST_FILE'] = 'PrinterActivityMonitorTests/Info.plist'
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.samduncan.PrinterActivityMonitorTests'
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  end

  # Add dependency on main target
  test_target.add_dependency(main_target)

  puts "Test target created successfully!"
end

# Find or create the test group
test_group = project.main_group.groups.find { |g| g.path == 'PrinterActivityMonitorTests' }

unless test_group
  test_group = project.main_group.new_group('PrinterActivityMonitorTests', 'PrinterActivityMonitorTests')
end

# Add test files to the project
test_files = [
  'PrinterActivityMonitorTests/HAAPIServiceTests.swift',
  'PrinterActivityMonitorTests/PrinterStateTests.swift',
  'PrinterActivityMonitorTests/EntityDiscoveryServiceTests.swift',
  'PrinterActivityMonitorTests/Info.plist'
]

test_files.each do |file_path|
  if File.exist?(file_path)
    # Check if file already exists in project
    existing_file = test_group.files.find { |f| f.path == File.basename(file_path) }

    unless existing_file
      file_ref = test_group.new_reference(file_path)

      # Add .swift files to the test target's sources build phase
      if file_path.end_with?('.swift')
        test_target.source_build_phase.add_file_reference(file_ref)
      end

      puts "Added #{file_path} to project"
    else
      puts "#{file_path} already in project"
    end
  else
    puts "Warning: #{file_path} not found"
  end
end

# Save the project
project.save

puts "\nTest target setup complete!"
puts "Next steps:"
puts "1. Open PrinterActivityMonitor.xcodeproj in Xcode"
puts "2. Go to Product → Scheme → Edit Scheme"
puts "3. Select 'Test' in the left sidebar"
puts "4. Click '+' and add PrinterActivityMonitorTests"
puts "5. Press Cmd+U to run tests"
