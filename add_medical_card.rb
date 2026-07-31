project_file = 'MedTracker.xcodeproj/project.pbxproj'
content = File.read(project_file)

unless content.include?('MedicalCardView.swift')
  # Generate UUIDs (using a simple random string generator for PBX format)
  def generate_uuid
    SecureRandom.hex(12).upcase[0, 24]
  end
  require 'securerandom'

  file_ref_uuid = generate_uuid
  build_file_uuid = generate_uuid

  # 1. Add PBXBuildFile
  build_file_str = "		#{build_file_uuid} /* MedicalCardView.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{file_ref_uuid} /* MedicalCardView.swift */; };\n"
  content.sub!("/* Begin PBXBuildFile section */\n", "/* Begin PBXBuildFile section */\n" + build_file_str)

  # 2. Add PBXFileReference
  file_ref_str = "		#{file_ref_uuid} /* MedicalCardView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MedicalCardView.swift; sourceTree = \"<group>\"; };\n"
  content.sub!("/* Begin PBXFileReference section */\n", "/* Begin PBXFileReference section */\n" + file_ref_str)

  # 3. Add to PBXGroup (Views)
  # Find the Views group and insert the file reference ID
  # Searching for:
  # /* Views */ = {
  #     isa = PBXGroup;
  #     children = (
  views_group_regex = /(\/\* Views \*\/ = \{\s*isa = PBXGroup;\s*children = \(\n)/
  child_str = "				#{file_ref_uuid} /* MedicalCardView.swift */,\n"
  content.sub!(views_group_regex, "\\1" + child_str)

  # 4. Add to PBXSourcesBuildPhase
  # Find the Sources build phase and insert the build file ID
  # Searching for:
  # /* Begin PBXSourcesBuildPhase section */
  # ...
  # files = (
  sources_phase_regex = /(isa = PBXSourcesBuildPhase;\s*buildActionMask = .*?;\s*files = \(\n)/
  build_file_entry = "				#{build_file_uuid} /* MedicalCardView.swift in Sources */,\n"
  content.sub!(sources_phase_regex, "\\1" + build_file_entry)

  File.write(project_file, content)
  puts "Added MedicalCardView.swift"
else
  puts "Already exists"
end
