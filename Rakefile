require 'spec/rake/spectask'
task :test => :spec
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList["spec/**/*_spec.rb"]
end

require 'tumbler'
Tumbler.use_rake_tasks

desc 'Default: run specs'
task :default => :spec
