require "bundler/gem_tasks"

# Locally, `rake release` only tags the version and pushes the commit and
# the tag. The Push Gem workflow (.github/workflows/gem_push.yml) then
# builds the gem and pushes it to RubyGems.org with trusted publishing. That
# workflow runs `rake release` too, so on GitHub Actions the task keeps
# Bundler's behavior and pushes the gem.
unless ENV["GITHUB_ACTIONS"]
  Rake::Task["release"].clear
  desc "Create tag #{Bundler::GemHelper.instance.send(:version_tag)} and push it, so GitHub Actions pushes the gem"
  task :release, [:remote] => %w[release:guard_clean release:source_control_push] do
    puts "The Push Gem workflow will push the gem: https://github.com/omniauth/omniauth-oauth2/actions/workflows/gem_push.yml"
  end
end
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new

task :test => :spec

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  task :rubocop do
    warn "Skipping RuboCop: it is not installed. It needs Ruby 2.7 or later; run `bundle install` there."
  end
end

begin
  require "steep"

  desc "Type-check lib against sig with Steep"
  task :steep do
    sh "rbs collection install"
    sh "steep check"
  end
rescue LoadError
  task :steep do
    warn "Skipping Steep: it is not installed. It needs CRuby 3.3 or later; run `bundle install` there."
  end
end

begin
  require "mutant"

  desc "Run mutation tests with mutant"
  task :mutant do
    sh "mutant run"
  end
rescue LoadError
  task :mutant do
    warn "Skipping mutant: it is not installed. It needs CRuby 3.3 or later; run `bundle install` there."
  end
end

task :default => %i[spec rubocop steep mutant]

begin
  require "duel/rake_task"
  Duel::RakeTask.new
rescue LoadError
  # Duel requires Ruby 3.4 or later
end
