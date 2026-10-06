use v5.40;
use feature 'class';
no warnings 'experimental::class';
use Alien::Xrepo::Runtime;
class Alien::SDL3 v1.0.0 : isa(Alien::Xrepo::Runtime) {

    # SDL3 is bound as a family: core + the common extension libraries. Each is installed
    # separately (as a SHARED library; xrepo builds SDL3 static by default, and Affix/FFI::Platypus
    # need a real .dll/.so/.dylib) and exposed via the Alien::Build-style `alt()` accessor or a
    # package-name argument.
    #
    # recipes/ is a small local xmake-repo tree (the libsdl3_ttf override); registering it here
    # means the runtime description also carries everything the engine needs to reproduce the
    # build.
    method recipe {
        return {
            name     => 'Alien-SDL3',
            packages => [
                { name => 'libsdl3',       kind => 'shared' },
                { name => 'libsdl3_image', kind => 'shared' },
                { name => 'libsdl3_ttf',   kind => 'shared' },
                { name => 'libsdl3_mixer', kind => 'shared' }
            ],

            # Ask for system packages explicitly: distro/brew copies of SDL3 and friends are preferred over
            # building the pinned sources, and anything the system does not provide still falls back to a
            # source build. Note this is deliberately not a hard requirement -- recipes/packages/l/libsdl3/
            # xmake.lua gates the system path on SDL3 >= 3.4.18, so an older distro copy (eg Ubuntu's 3.4.2)
            # is skipped rather than mixed with the 3.4.18 headers the extension libraries build against.
            defaults    => { system => 1 },
            local_repos => ['recipes']
        };
    }
    }
    #
    1;
