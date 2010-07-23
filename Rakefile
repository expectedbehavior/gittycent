require 'spec/rake/spectask'


Spec::Rake::SpecTask.new do |t|
  # t.warning = true
  # t.rcov = true
end

task :test => :spec
task :default => :spec

require 'tumbler'
Tumbler.use_rake_tasks
