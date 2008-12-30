require 'rubygems'

Gem::manage_gems

require 'rake/gempackagetask'
require 'rake/rdoctask'

PKG_NAME           = 'rwikibot'
PKG_VERSION        = '2.0.0'
PKG_FILE_NAME      = "#{PKG_NAME}-#{PKG_VERSION}"
RUBY_FORGE_PROJECT = 'rwikibot'
RUBY_FORGE_USER    = 'eddieroger'

spec = Gem::Specification.new do |s|
	s.platform = Gem::Platform::RUBY
	s.name = PKG_NAME
	s.version = PKG_VERSION
	s.author = "Eddie Roger"
	s.email = "eddieroger @nospam@ gmail.com"
	s.summary = "A library for creating MediaWiki bots."
	s.homepage = "http://www.rwikibot.net"
	s.rubyforge_project = 'RWikiBot'
	s.files = FileList['lib/*.rb', 'test/*'].to_a
	s.require_path = "lib"
  s.test_files = Dir.glob('tests/*.rb')
	s.has_rdoc = 'true'
	s.rdoc_options = ['--inline-source --force-update']
	s.extra_rdoc_files = ["README", "CHANGELOG"]
end

Rake::GemPackageTask.new(spec) do |pkg|
	pkg.need_tar = true
end

Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = "#{PKG_NAME} -- the best way to create MediaWiki bots in Ruby"
  rdoc.options << "--inline-source"
  rdoc.rdoc_files.include('README', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

task :default => "pkg/#{spec.name}-#{spec.version}.gem" do
	puts "generated latest version"
end