project_file = 'MedTracker.xcodeproj/project.pbxproj'
content = File.read(project_file)

unless content.include?('SplashView.swift')
  require 'securerandom'
  def generate_uuid; SecureRandom.hex(12).upcase[0, 24]; end

  file_ref_uuid = generate_uuid
  build_file_uuid = generate_uuid

  build_file_str = "		#{build_file_uuid} /* SplashView.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{file_ref_uuid} /* SplashView.swift */; };\n"
  content.sub!("/* Begin PBXBuildFile section */\n", "/* Begin PBXBuildFile section */\n" + build_file_str)

  file_ref_str = "		#{file_ref_uuid} /* SplashView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SplashView.swift; sourceTree = \"<group>\"; };\n"
  content.sub!("/* Begin PBXFileReference section */\n", "/* Begin PBXFileReference section */\n" + file_ref_str)

  views_group_regex = /(\/\* Views \*\/ = \{\s*isa = PBXGroup;\s*children = \(\n)/
  child_str = "				#{file_ref_uuid} /* SplashView.swift */,\n"
  content.sub!(views_group_regex, "\\1" + child_str)

  sources_phase_regex = /(isa = PBXSourcesBuildPhase;\s*buildActionMask = .*?;\s*files = \(\n)/
  build_file_entry = "				#{build_file_uuid} /* SplashView.swift in Sources */,\n"
  content.sub!(sources_phase_regex, "\\1" + build_file_entry)

  File.write(project_file, content)
  puts "Added SplashView.swift"
else
  puts "Already exists"
end
