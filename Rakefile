require 'spec/rake/spectask'

require 'echoe'
Echoe.new 'gittycent' do |p|
  p.description     = "A GitHub wrapper in Ruby."
  p.url             = "http://github.com/fastestforward/gittycent"
  p.author          = "Elijah Miller"
  p.email           = "elijah.miller@gmail.com"
  p.retain_gemspec  = true
  p.need_tar_gz     = false
  p.extra_deps      = [
  ]
end

desc 'Default: run specs'
task :default => :spec
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList["spec/**/*_spec.rb"]
end

task :test => :spec
