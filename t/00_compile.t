use lib '../lib/', '../blib/lib/';
use Test2::V0;
#
use Alien::SDL3;
#
note 'Libs:';
note '  - ' . $_ for sort Alien::SDL3->dynamic_libs;
note sprintf '%s support: %s', $_, Alien::SDL3->features->{$_} ? 'yes' : 'no'
    for qw[SDL3 SDL3_image SDL3_mixer SDL3_ttf];
#
isa_ok( Alien::SDL3->sdldir, ['Path::Tiny'] );
isa_ok( Alien::SDL3->incdir, ['Path::Tiny'] );
isa_ok( Alien::SDL3->libdir, ['Path::Tiny'] );
#
Alien::SDL3->incdir->visit( sub { diag $_->realpath } );
Alien::SDL3->libdir->visit( sub { diag $_->realpath } );
#
done_testing;
