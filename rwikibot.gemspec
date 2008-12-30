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
	s.add_dependency('deep_merge',["> 0.0.0"])
	s.add_dependency('xml-simple',["> 0.0.0"])
end