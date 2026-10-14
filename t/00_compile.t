use v5.40;
use blib;
use Test2::V0;
use Alien::SDL3;
use feature 'try';
#
try { require Affix } catch ($e) {
    skip_all 'Needs Affix'
}
my $sdl3  = Alien::SDL3->new;
my $built = $sdl3->has_snapshot;    # a snapshot was written: every package must then resolve
isa_ok $sdl3, ['Alien::SDL3'],           'isa Alien::SDL3';
isa_ok $sdl3, ['Alien::Xrepo::Runtime'], 'isa Alien::Xrepo::Runtime';

# Surface whatever the build recorded for packages it could not produce, so a smoker's
# log shows the failure instead of it hiding inside the snapshot.
if ( my $errors = $sdl3->snapshot_errors ) {
    diag "$_ failed to install: $errors->{$_}" for sort keys %$errors;
}

#~ is [ $sdl3->package_names ], [ 'libsdl3', 'libsdl3_image', 'libsdl3_ttf', 'libsdl3_mixer' ], 'package_names lists the SDL3 family';
#
for my $name ( $sdl3->package_names ) {
    my $alt  = $sdl3->alt($name);
    my $info = $alt->package_info;
    unless ($info) {
        diag $name . ' is missing';

        # A built dist that cannot resolve one of its packages is broken, so fail rather
        # than pass -- otherwise a partial/failed install is reported green. A cold
        # checkout legitimately has no snapshot, so there we only diagnose.
        ok !$built, "$name resolved" if $built;
        next;
    }
    diag sprintf '%-16s v%-9s %-8s',  $name, $info->version, $info->kind;
    diag sprintf '  installdir : %s', $info->installdir // '(none)';
    diag sprintf '  libpath    : %s', $info->libpath    // '(none)';
    diag sprintf '  dynamic    : %s', join( '; ', @{ $info->libfiles    // [] } ) || '(none)';
    diag sprintf '  includes   : %s', join( '; ', @{ $info->includedirs // [] } ) || '(none)';
    diag sprintf '  cflags     : %s', $alt->cflags;
    diag sprintf '  libs       : %s', $alt->libs;
}
#
done_testing;
