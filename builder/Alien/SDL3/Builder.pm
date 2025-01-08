# Based on Module::Build::Tiny which is copyright (c) 2011 by Leon Timmermans, David Golden.
# Module::Build::Tiny is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
use v5.38;
use feature 'class';
no warnings 'experimental::class', 'experimental::builtin';
class    #
    Alien::SDL3::Builder {
    use CPAN::Meta;
    use ExtUtils::Install qw[pm_to_blib install];
    use ExtUtils::InstallPaths 0.002;
    use File::Basename        qw[basename dirname];
    use File::Find            ();
    use File::Path            qw[mkpath rmtree];
    use File::Spec::Functions qw[catfile catdir rel2abs abs2rel splitdir curdir];
    use JSON::PP 2            qw[encode_json decode_json];
    use Config;
    use Carp qw[croak];
    use Env  qw[@PATH];
    use HTTP::Tiny;

    # Not in CORE
    use Alien::cmake3;
    use Path::Tiny qw[cwd path tempdir];
    use ExtUtils::Helpers 0.028 qw[make_executable split_like_shell detildefy];
    use Devel::CheckBin;
    #
    field $action : param //= 'build';
    field $meta = CPAN::Meta->load_file('META.json');

    # https://wiki.libsdl.org/SDL3/Installation
    #~ apt-get install libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
    #~ pacman -S sdl2 sdl2_image sdl2_mixer sdl2_ttf
    #~ dnf install SDL2-devel SDL2_image-devel SDL2_mixer-devel SDL2_ttf-devel
    #~ https://github.com/libsdl-org/setup-sdl/issues/20
    # TODO: Write a GH action to test with libs preinstalled
    #~ field $SDL_version : param       //= '2.30.11';
    field $SDL_version : param       //= '3.1.6';
    field $SDL_image_version : param //= '2.8.4';
    field $SDL_mixer_version : param //= '2.8.0';
    field $SDL_ttf_version : param   //= '2.24.0';
    field $SDL_rtf_version : param   //= '';
    field @liblist = qw[SDL3 SDL2_image SDL2_mixer SDL2_ttf SDL2_rtf];
    field $http;
    field %config;
    #
    unshift @PATH, Alien::cmake3->bin_dir;

    # Params to Build script
    field $install_base : param  //= '';
    field $installdirs : param   //= '';
    field $uninst : param        //= 0;    # Make more sense to have a ./Build uninstall command but...
    field $install_paths : param //= ExtUtils::InstallPaths->new( dist_name => $meta->name );
    field $verbose : param       //= 0;
    field $dry_run : param       //= 0;
    field $pureperl : param      //= 0;
    field $jobs : param          //= 1;
    field $destdir : param       //= '';
    field $prefix : param        //= '';
    field $cwd = cwd()->absolute;
    #
    #
    ADJUST {
        -e 'META.json' or die "No META information provided\n";
    }
    method write_file( $filename, $content ) { path($filename)->spew_raw($content) or die "Could not open $filename: $!\n" }
    method read_file ($filename)             { path($filename)->slurp_utf8         or die "Could not open $filename: $!\n" }

    method step_build() {
        $self->step_build_libs;
        for my $pl_file ( find( qr/\.PL$/, 'lib' ) ) {
            ( my $pm = $pl_file ) =~ s/\.PL$//;
            system $^X, $pl_file->stringify, $pm and die "$pl_file returned $?\n";
        }
        my %modules       = map { $_ => catfile( 'blib', $_ ) } find( qr/\.pm$/,  'lib' );
        my %docs          = map { $_ => catfile( 'blib', $_ ) } find( qr/\.pod$/, 'lib' );
        my %scripts       = map { $_ => catfile( 'blib', $_ ) } find( qr/(?:)/,   'script' );
        my %sdocs         = map { $_ => delete $scripts{$_} } grep {/.pod$/} keys %scripts;
        my %dist_shared   = map { $_ => catfile( qw[blib lib auto share dist],   $meta->name, abs2rel( $_, 'share' ) ) } find( qr/(?:)/, 'share' );
        my %module_shared = map { $_ => catfile( qw[blib lib auto share module], abs2rel( $_, 'module-share' ) ) } find( qr/(?:)/, 'module-share' );
        pm_to_blib( { %modules, %docs, %scripts, %dist_shared, %module_shared }, catdir(qw[blib lib auto]) );
        make_executable($_) for values %scripts;
        mkpath( catdir(qw[blib arch]), $verbose );
        0;
    }
    method step_clean() { rmtree( $_, $verbose ) for qw[blib temp]; 0 }

    method step_install() {
        $self->step_build() unless -d 'blib';
        install(
            [   from_to           => $install_paths->install_map,
                verbose           => $verbose,
                dry_run           => $dry_run,
                uninstall_shadows => $uninst,
                skip              => undef,
                always_copy       => 1
            ]
        );
        0;
    }
    method step_realclean () { rmtree( $_, $verbose ) for qw[blib temp Build _build_params MYMETA.yml MYMETA.json]; 0 }

    method step_test() {
        $self->step_build() unless -d 'blib';
        require TAP::Harness::Env;
        my %test_args = (
            ( verbosity => $verbose ),
            ( jobs  => $jobs ),
            ( color => -t STDOUT ),
            lib => [ map { rel2abs( catdir( 'blib', $_ ) ) } qw[arch lib] ],
        );
        TAP::Harness::Env->create( \%test_args )->runtests( sort map { $_->stringify } find( qr/\.t$/, 't' ) )->has_errors;
    }

    method _do_in_dir( $path, $sub ) {
        my $cwd = cwd()->absolute;
        chdir $path->absolute->stringify if -d $path->absolute;
        $sub->();
        chdir $cwd->stringify;
    }

    method step_build_libs() {
        my $pre = cwd->absolute->child( qw[blib arch auto], $meta->name );
        return 0 if -d $pre;
        $pre->child('lib')->mkdir;
        my $p = $cwd->child('share')->realpath;
        $p->mkdir;
        $p->child('lib')->mkdir();

        #~ $self->share_dir( $p->stringify );
        if ( $^O eq 'MSWin32' ) {    # pretend we're 64bit
            my %archives = (
                SDL3       => ["https://github.com/libsdl-org/SDL/releases/download/preview-${SDL_version}/SDL3-${SDL_version}-win32-x64.zip"],
                SDL2_image => [
                    "https://github.com/libsdl-org/SDL_image/releases/download/release-${SDL_image_version}/SDL2_image-${SDL_image_version}-win32-x64.zip"
                ],
                SDL2_mixer => [
                    "https://github.com/libsdl-org/SDL_mixer/releases/download/release-${SDL_mixer_version}/SDL2_mixer-${SDL_mixer_version}-win32-x64.zip",
                    undef,    # flags
                    'You may need to install various dev packages (flac, vorbis, opus, etc.)'
                ],
                SDL2_ttf =>
                    ["https://github.com/libsdl-org/SDL_ttf/releases/download/release-${SDL_ttf_version}/SDL2_ttf-${SDL_ttf_version}-win32-x64.zip"]
            );
            for my $lib ( grep { defined $archives{$_} } @liblist ) {
                next if defined $config{$lib};
                my $store = tempdir()->child( $lib . '.zip' );
                my $okay  = $self->fetch( $archives{$lib}->[0], $store );
                if ( !$okay ) {
                    die 'Failed to fetch SDL binaries' if $lib eq 'SDL3';
                    next;
                }

                #~ $self->add_to_cleanup( $okay->canonpath );
                $okay->visit(
                    sub {
                        my ( $path, $state ) = @_;
                        $path->copy( $p->child( 'lib', $path->basename ) ) if /\.dll$/;
                    },
                    { recurse => 1 }
                );
                $config{$lib}{type} = 'share';
                $config{$lib}{okay} = 1;
            }

            #~ ...;
        }
        else {
            my %archives = (
                SDL3       => ["https://github.com/libsdl-org/SDL/releases/download/preview-${SDL_version}/SDL3-${SDL_version}.tar.gz"],
                SDL2_image =>
                    ["https://github.com/libsdl-org/SDL_image/releases/download/release-${SDL_image_version}/SDL2_image-${SDL_image_version}.tar.gz"],
                SDL2_mixer => [
                    "https://github.com/libsdl-org/SDL_mixer/releases/download/release-${SDL_mixer_version}/SDL2_mixer-${SDL_mixer_version}.tar.gz",
                    undef,    # flags
                    'You may need to install various dev packages (flac, vorbis, opus, etc.)'
                ],
                SDL2_ttf => ["https://github.com/libsdl-org/SDL_ttf/releases/download/release-${SDL_ttf_version}/SDL2_ttf-${SDL_ttf_version}.tar.gz"],

                #~ SDL2_rtf => ['https://github.com/libsdl-org/SDL_rtf/archive/refs/heads/main.tar.gz']
            );
            for my $lib ( grep { defined $archives{$_} } @liblist ) {
                require DynaLoader;
                my ($path) = DynaLoader::dl_findfile( '-l' . $lib );
                if ($path) {
                    $config{$lib}{type} = 'system';
                    $config{$lib}{path} = path($path)->realpath->stringify;
                    next;
                }
                my $store = tempdir()->child( $lib . '.tar.gz' );
                my $build = tempdir()->child('build');
                my $okay  = $self->fetch( $archives{$lib}->[0], $store );
                if ( !$okay ) {
                    die 'Failed to download SDL3 source' if $lib eq 'SDL3';
                    next;
                }
                next if !$okay;

                #~ $self->add_to_cleanup( $okay->canonpath );
                $config{$lib}{path} = 'share';
                $config{$lib}{okay} = 0;
                if ( path($okay)->child( 'external', 'download.sh' )->exists && Devel::CheckBin::can_run('git') ) {
                    $self->_do_in_dir(
                        path($okay)->child('external'),
                        sub {
                            system 'sh', 'download.sh';
                        }
                    );
                    $archives{$lib}->[1] = '-DSDL3MIXER_VENDORED=ON';
                }
                {
                    $self->_do_in_dir(
                        $okay,
                        sub {
                            system( Alien::cmake3->exe, grep {length} '-S ' . $okay,
                                '-B ' . $build->canonpath,      '--install-prefix=' . $p->canonpath,
                                '-Wdeprecated -Wdev -Werror',   '-DSDL_SHARED=ON',
                                '-DSDL_TESTS=OFF',              '-DSDL_INSTALL_TESTS=OFF',
                                '-DSDL_DISABLE_INSTALL_MAN=ON', '-DSDL_VENDOR_INFO=SDL3.pm',
                                '-DCMAKE_BUILD_TYPE=Release',   '-DSDL3_DIR=' . $cwd->child('share')->absolute,
                                $archives{$lib}->[1]
                            );
                            system( Alien::cmake3->exe, '--build', $build->canonpath

                                #, '--config Release', '--parallel'
                            );
                            if ( !system( Alien::cmake3->exe, '--install', $build->canonpath ) ) {
                                $config{$lib}{okay} = 1;
                            }
                            else {
                                printf STDERR "Failed to build %s! %s\n", $lib, $archives{$lib}->[2] // '';
                                die if $lib eq 'SDL3';
                            }
                        }
                    );
                }
            }
        }
        {
            my @out;
            for my $section ( sort keys %config ) {
                push @out, sprintf '[%s]',    $section;
                push @out, sprintf '%s = %s', $_, $config{$section}{$_} for sort keys %{ $config{$section} };
                push @out, '';    # Add extra newline between sections
            }
            $p->child('.config')->spew( join "\n", @out );
        }
    }

    method get_arguments (@sources) {
        $_ = detildefy($_) for grep {defined} $install_base, $destdir, $prefix, values %{$install_paths};
        $install_paths = ExtUtils::InstallPaths->new( dist_name => $meta->name );
        return;
    }

    method fetch ( $liburl, $outfile ) {
        $http //= HTTP::Tiny->new();
        say sprintf 'Downloading %s... ', $liburl if $verbose;
        $outfile->parent->mkpath;
        my $response = $http->mirror( $liburl, $outfile, {} );
        if ( $response->{success} ) {    #ddx $response;

            #~ $self->add_to_cleanup($outfile);
            say 'okay' if $verbose;
            my $outdir = $outfile->parent->child( $outfile->basename( '.tar.gz', '.zip' ) );
            printf 'Extracting %s to %s... ', $outfile, $outdir if $verbose;
            require Archive::Extract;
            my $ae = Archive::Extract->new( archive => $outfile );
            if ( $ae->extract( to => $outdir ) ) {
                say 'okay' if $verbose;

                #~ $self->add_to_cleanup( $ae->extract_path );
                return path( $ae->extract_path );
            }
            else {
                croak 'Failed to extract ' . $outfile;
            }
        }
        else {
            croak 'Failed to download ' . $liburl;
        }
        return 0;
    }

    method Build(@args) {
        my $method = $self->can( 'step_' . $action );
        $method // die "No such action '$action'\n";
        exit $method->($self);
    }

    method Build_PL() {
        say sprintf 'Creating new Build script for %s %s', $meta->name, $meta->version;
        $self->write_file( 'Build', sprintf <<'', $^X, __PACKAGE__, __PACKAGE__ );
#!%s
use lib 'builder';
use %s;
use Getopt::Long qw[GetOptionsFromArray];
my %%opts = ( @ARGV && $ARGV[0] =~ /\A\w+\z/ ? ( action => shift @ARGV ) : () );
GetOptionsFromArray \@ARGV, \%%opts, qw[install_base=s install_path=s%% installdirs=s destdir=s prefix=s config=s%% uninst:1 verbose:1 dry_run:1 jobs=i];
%s->new(%%opts)->Build();

        make_executable('Build');
        my @env = defined $ENV{PERL_MB_OPT} ? split_like_shell( $ENV{PERL_MB_OPT} ) : ();
        $self->write_file( '_build_params', encode_json( [ \@env, \@ARGV ] ) );
        if ( my $dynamic = $meta->custom('x_dynamic_prereqs') ) {
            my %meta = ( %{ $meta->as_struct }, dynamic_config => 0 );
            $self->get_arguments( \@env, \@ARGV );
            require CPAN::Requirements::Dynamic;
            my $dynamic_parser = CPAN::Requirements::Dynamic->new();
            my $prereq         = $dynamic_parser->evaluate($dynamic);
            $meta{prereqs} = $meta->effective_prereqs->with_merged_prereqs($prereq)->as_string_hash;
            $meta = CPAN::Meta->new( \%meta );
        }
        $meta->save(@$_) for ['MYMETA.json'];
    }

    sub find ( $pattern, $base ) {
        $base = path($base) unless builtin::blessed $base;
        my $blah = $base->visit(
            sub ( $path, $state ) {
                $state->{$path} = $path if -f $path && $path =~ $pattern;

                #~ return \0 if keys %$state == 10;
            },
            { recurse => 1 }
        );
        values %$blah;
    }
    };
1;
