require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'
spec = Gem::Specification.new do |s|
	s.platform = Gem::Platform::RUBY
	s.name = "rwikibot"
	s.version = "1.2"
	s.author = "Eddie Roger"
	s.email = "eddieroger @nospam@ gmail.com"
	s.summary = "A library for creating MediaWiki bots."
	s.files = FileList['lib/*.rb', 'test/*'].to_a
	s.require_path = "lib"
	s.autorequire = "rwikibot"
  s.test_files = Dir.glob('tests/*.rb')
	s.has_rdoc = 'true'
	s.rdoc_options = ['--inline-source']
	s.extra_rdoc_files = ["README", "CHANGELOG"]
end
Rake::GemPackageTask.new(spec) do |pkg|
	pkg.need_tar = true
end
task :default => "pkg/#{spec.name}-#{spec.version}.gem" do
	puts "generated latest version"
end