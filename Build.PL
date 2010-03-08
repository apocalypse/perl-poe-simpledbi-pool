use Module::Build;
my $build = Module::Build->new(
	# look up Module::Build::API for the info!
	'dynamic_config'	=> 0,
	'module_name'		=> 'POE::Component::SimpleDBI::PoolManager',
	'license'		=> 'perl',

	'dist_abstract'		=> 'Pool manager for SimpleDBI',
	'dist_author'		=> 'Apocalypse <APOCAL@cpan.org>',

	'create_packlist'	=> 1,
	'create_makefile_pl'	=> 'traditional',
	'create_readme'		=> 1,

	'test_files'		=> 't/*.t',

	'requires'		=> {
		# set our basic perl version
		'perl'	=> '5.8.8',

		# POE Stuff
		'POE'					=> 0,
		'POE::Component::SimpleDBI'		=> '1.19',
		'POE::Session::AttributeBased'		=> '0.07',
	},

	'recommends'		=> {
		# Test stuff
		'Test::More'		=> 0,

		'Test::Compile'		=> 0,
		'Test::Perl::Critic'	=> 0,
		'Test::Dependencies'	=> 0,
		'Test::Distribution'	=> 0,
		'Test::Fixme'		=> 0,
		'Test::HasVersion'	=> 0,
		'Test::Kwalitee'	=> 0,
		'Test::CheckManifest'	=> 0,
		'Test::MinimumVersion'	=> 0,
		'Test::Pod::Coverage'	=> 0,
		'Test::Spelling'	=> 0,
		'Test::Pod'		=> 0,
		'Test::Prereq'		=> 0,
		'Test::Strict'		=> 0,
		'Test::UseAllModules'	=> 0,
	},
);

# all done!
$build->create_build_script;
