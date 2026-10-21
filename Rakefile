#!/usr/bin/env rake

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new

task :test => :spec

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  task :rubocop do
    $stderr.puts "RuboCop is disabled"
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

task :default => %i[spec rubocop steep]
