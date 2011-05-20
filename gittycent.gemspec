# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{gittycent}
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Elijah Miller"]
  s.date = %q{2011-05-20}
  s.description = %q{A GitHub wrapper in Ruby.}
  s.email = %q{elijah.miller@gmail.com}
  s.extra_rdoc_files = ["CHANGELOG", "LICENSE", "README.rdoc", "lib/gittycent.rb", "lib/gittycent/version.rb"]
  s.files = ["CHANGELOG", "LICENSE", "Manifest", "README.rdoc", "Rakefile", "gittycent.gemspec", "lib/gittycent.rb", "lib/gittycent/version.rb", "spec/gittycent_spec.rb", "spec/spec_helper.rb"]
  s.homepage = %q{http://github.com/fastestforward/gittycent}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Gittycent", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{gittycent}
  s.rubygems_version = %q{1.6.1}
  s.summary = %q{A GitHub wrapper in Ruby.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
