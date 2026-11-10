# Prints the release notes for a version from CHANGELOG.md:
#
#   ruby .github/release_notes.rb v1.2.3
#
# GitHub shows every line break in release notes, so the changelog's
# hard-wrapped lines are joined back up, except in code blocks. Reference
# links, like [#12], are resolved, since their definitions are at the
# bottom of the changelog, and the compare link is added at the end.

version = ARGV.fetch(0).delete_prefix("v")
changelog = File.read(File.expand_path("../CHANGELOG.md", __dir__))

section = changelog[/^## \[#{Regexp.escape(version)}\][^\n]*\n(.*?)(?=^## \[|^\[[^\]]+\]: )/m, 1]
abort "CHANGELOG.md has no section for #{version}" unless section

links = changelog.scan(/^\[([^\]]+)\]: (\S+)$/).to_h

lines = []
fenced = false
section.strip.each_line(:chomp => true) do |line|
  if line.strip.start_with?("```")
    fenced = !fenced
    lines << line
  elsif fenced || line.strip.empty? || lines.empty? || lines.last.strip.empty? ||
        lines.last.start_with?("#") || line =~ /\A\s*([-*+]|\d+\.|#|>|\|)\s/
    lines << line
  else
    lines[-1] = "#{lines.last} #{line.strip}"
  end
end
notes = lines.join("\n")

# [label] with no (url) or [ref] after it, defined at the bottom
notes = notes.gsub(/\[([^\]]+)\](?![(\[:])/) do
  links.key?(Regexp.last_match(1)) ? "[#{Regexp.last_match(1)}](#{links[Regexp.last_match(1)]})" : Regexp.last_match(0)
end

compare = links[version]
notes += "\n\n**Full Changelog**: #{compare}" if compare
puts notes
