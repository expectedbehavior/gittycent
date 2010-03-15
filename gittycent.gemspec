# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{gittycent}
  s.version = "0.0.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Elijah Miller"]
  s.date = %q{2010-03-13}
  s.description = %q{A GitHub wrapper in Ruby.}
  s.email = %q{elijah.miller@gmail.com}
  s.extra_rdoc_files = ["CHANGELOG", "LICENSE", "README.rdoc", "lib/gittycent.rb"]
  s.files = ["CHANGELOG", "LICENSE", "Manifest", "README.rdoc", "Rakefile", "gittycent.gemspec", "lib/gittycent.rb"]
  s.homepage = %q{http://github.com/fastestforward/gittycent}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Gittycent", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{gittycent}
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{A GitHub wrapper in Ruby.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
