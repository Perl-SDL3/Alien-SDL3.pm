package builder::Alien {
    use strict;
    use warnings;
    use base 'Module::Build';
    use HTTP::Tiny;
    use Path::Tiny qw[path tempdir];
    use ExtUtils::CBuilder;
    use Config;
    use Env qw[@PATH];
    use Alien::cmake3;
    use Devel::CheckBin;
    use Carp;
    $|++;

    # https://wiki.libsdl.org/SDL3/Installation
    #~ apt-get install libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
    #~ pacman -S sdl2 sdl2_image sdl2_mixer sdl2_ttf
    #~ dnf install SDL2-devel SDL2_image-devel SDL2_mixer-devel SDL2_ttf-devel
    #~ https://github.com/libsdl-org/setup-sdl/issues/20
    my $SDL_version       = '2.30.1';
    my $SDL_image_version = '2.8.2';
    my $SDL_mixer_version = '2.8.0';
    my $SDL_ttf_version   = '2.22.0';
    my @liblist           = qw[SDL3 SDL3_image SDL3_mixer SDL3_ttf];
    #
    unshift @PATH, Alien::cmake3->bin_dir;
    #
    sub fetch {
        my ( $self, $liburl, $outfile ) = @_;
        CORE::state $http //= HTTP::Tiny->new();
        printf 'Downloading %s... ', $liburl unless $self->quiet;
        $outfile->parent->mkpath;
        my $response = $http->mirror( $liburl, $outfile, {} );
        if ( $response->{success} ) {    #ddx $response;
            $self->add_to_cleanup($outfile);
            CORE::say 'okay' unless $self->quiet;
            my $outdir = $outfile->parent->child( $outfile->basename( '.tar.gz', '.zip' ) );
            printf 'Extracting %s to %s... ', $outfile, $outdir unless $self->quiet;
            require Archive::Extract;
            my $ae = Archive::Extract->new( archive => $outfile );
            if ( $ae->extract( to => $outdir ) ) {
                CORE::say 'okay' unless $self->quiet;
                $self->add_to_cleanup( $ae->extract_path );
                return path( $ae->extract_path );
            }
            else {
                warn 'Failed to extract ' . $outfile;
            }
        }
        else {
            warn 'Failed to download ' . $liburl;
        }
        return 0;
    }

    sub ACTION_code {
        my $self = shift;
        my $p    = path( $self->base_dir )->child('share');
        $p->mkdir;
        $p->child('lib')->mkdir();
        $self->share_dir( $p->realpath->stringify );
        if ( $^O eq 'MSWin32' ) {    # pretend we're 64bit
            my %archives = (
                SDL3 => [
                    "https://github.com/libsdl-org/SDL/releases/download/release-${SDL_version}/SDL2-${SDL_version}-win32-x64.zip"
                ],
                SDL3_image => [
                    "https://github.com/libsdl-org/SDL_image/releases/download/release-${SDL_image_version}/SDL2_image-${SDL_image_version}-win32-x64.zip"
                ],
                SDL3_mixer => [
                    "https://github.com/libsdl-org/SDL_mixer/releases/download/release-${SDL_mixer_version}/SDL2_mixer-${SDL_mixer_version}-win32-x64.zip",
                    undef,    # flags
                    'You may need to install various dev packages (flac, vorbis, opus, etc.)'
                ],
                SDL3_ttf => [
                    "https://github.com/libsdl-org/SDL_ttf/releases/download/release-${SDL_ttf_version}/SDL2_ttf-${SDL_ttf_version}-win32-x64.zip"
                ]
            );
            for my $lib ( grep { defined $archives{$_} } @liblist ) {
                next if $self->feature($lib);
                my $store = tempdir()->child( $lib . '.zip' );
                my $okay  = $self->fetch( $archives{$lib}->[0], $store );
                if ( !$okay ) {
                    die 'Failed to fetch SDL3 binaries' if $lib eq 'SDL3';
                    next;
                }
                $self->add_to_cleanup( $okay->canonpath );
                $okay->visit(
                    sub {
                        my ( $path, $state ) = @_;
                        $path->copy( $p->child( 'lib', $path->basename ) ) if /\.dll$/;
                    },
                    { recurse => 1 }
                );
                $self->config_data( $lib => 1 );
                $self->feature( $lib => 1 );
            }

            #~ ...;
        }
        else {
            my %archives = (
                SDL3 => [
                    "https://github.com/libsdl-org/SDL/releases/download/release-${SDL_version}/SDL2-${SDL_version}.tar.gz"
                ],
                SDL3_image => [
                    "https://github.com/libsdl-org/SDL_image/releases/download/release-${SDL_image_version}/SDL2_image-${SDL_image_version}.tar.gz"
                ],
                SDL3_mixer => [
                    "https://github.com/libsdl-org/SDL_mixer/releases/download/release-${SDL_mixer_version}/SDL2_mixer-${SDL_mixer_version}.tar.gz",
                    undef,    # flags
                    'You may need to install various dev packages (flac, vorbis, opus, etc.)'
                ],
                SDL3_ttf => [
                    "https://github.com/libsdl-org/SDL_ttf/releases/download/release-${SDL_ttf_version}/SDL2_ttf-${SDL_ttf_version}.tar.gz"
                ]
            );
            for my $lib ( grep { defined $archives{$_} } @liblist ) {
                next if $self->feature($lib);
                {    # TODO: Write a GH action to test with libs preinstalled
                    require File::Temp;    # Prefer Path::Tiny...
                    my ( $fh, $filename ) = File::Temp::tempfile(
                        'probe_lib' . $lib . '_XXXX',
                        SUFFIX => '.c',
                        TMPDIR => 1
                    );
                    syswrite $fh, 'int main(){return 1;}';
                    require ExtUtils::CBuilder;    # Core
                    my $b        = ExtUtils::CBuilder->new( quiet => 1 );
                    my $obj_file = $b->compile( source => $filename );

                    # TODO: gather the location (see Affix::locate_lib(...))
                    next if eval {
                        $b->link(                  # prefer Try::Tiny
                            objects            => $obj_file,
                            extra_linker_flags => '-lSDL3main -l' . $lib
                        );
                    };
                }
                my $store = tempdir()->child( $lib . '.tar.gz' );
                my $build = tempdir()->child('build');
                my $okay  = $self->fetch( $archives{$lib}->[0], $store );
                if ( !$okay ) {
                    die if $lib eq 'SDL3';
                    next;
                }
                next if !$okay;
                $self->add_to_cleanup( $okay->canonpath );
                $self->config_data( $lib => 1 );
                $self->feature( $lib => 0 );
                if ( path($okay)->child( 'external', 'download.sh' )->exists &&
                    Devel::CheckBin::check_bin('git') ) {
                    $self->_do_in_dir(
                        path($okay)->child('external'),
                        sub {
                            $self->do_system( 'sh', 'download.sh' );
                        }
                    );
                    $archives{$lib}->[1] = '-DSDL3MIXER_VENDORED=ON';
                }
                else {
                    $self->_do_in_dir(
                        $okay,
                        sub {
                            $self->do_system(
                                Alien::cmake3->exe,
                                grep {length} '-S ' . $okay,
                                '-B ' . $build->canonpath,
                                '--install-prefix=' . $p->canonpath,
                                '-Wdeprecated -Wdev -Werror',
                                '-DSDL_SHARED=ON',
                                '-DSDL_TESTS=OFF',
                                '-DSDL_INSTALL_TESTS=OFF',
                                '-DSDL_DISABLE_INSTALL_MAN=ON',
                                '-DSDL_VENDOR_INFO=SDL3.pm',
                                '-DCMAKE_BUILD_TYPE=Release',
                                '-DSDL3_DIR=' . $self->share_dir->{dist},
                                $archives{$lib}->[1]
                            );
                            $self->do_system(
                                Alien::cmake3->exe, '--build', $build->canonpath

                                #, '--config Release', '--parallel'
                            );
                            if (
                                $self->do_system(
                                    Alien::cmake3->exe, '--install', $build->canonpath
                                )
                            ) {
                                $self->feature( $lib => 1 );
                            }
                            else {
                                $self->feature( $lib => 0 );
                                printf STDERR "Failed to build %s! %s\n", $lib,
                                    $archives{$lib}->[2] // '';
                                die if $lib eq 'SDL3';
                            }
                        }
                    );
                }
            }
        }
        $self->SUPER::ACTION_code;
    }
}
