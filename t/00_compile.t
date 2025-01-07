use Test2::V0 '!subtest';
use Test2::Util::Importer 'Test2::Tools::Subtest' => ( subtest_streamed => { -as => 'subtest' } );
use lib 'lib', '../lib', 'blib/lib', '../blib/lib';
use Alien::SDL3;
#
diag 'Alien::SDL3::VERSION == ' . $Alien::SDL3::VERSION;
#
diag 'Libs:';
diag '  - ' . $_ for sort Alien::SDL3->dynamic_libs;
diag sprintf '%s support: %s', $_, Alien::SDL3->features->{$_}{okay} ? 'yes' : 'no' for qw[SDL3 SDL3_image SDL3_mixer SDL3_ttf];
#
isa_ok( Alien::SDL3->sdldir, ['Path::Tiny'], 'sdldir' );
isa_ok( Alien::SDL3->incdir, ['Path::Tiny'], 'incdir' );
isa_ok( Alien::SDL3->libdir, ['Path::Tiny'], 'libdir' );
#
Alien::SDL3->incdir->visit( sub { diag $_->realpath } );
Alien::SDL3->libdir->visit( sub { diag $_->realpath } );
#
done_testing;
