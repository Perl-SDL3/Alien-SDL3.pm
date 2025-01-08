package Alien::SDL3 0.04 {
    use v5.36;
    use Path::Tiny;
    use Carp;
    use Config;
    #
    my $base;
    {
        my $path = path( qw[auto share dist], ( __PACKAGE__ =~ s[::][-]rg ) );
        for ( map { path($_) } @INC, map { path(__FILE__)->parent->parent->sibling($_)->absolute } qw[share blib] ) {
            $_->visit(
                sub ( $p, $s ) {
                    return unless -d $p;
                    my $d = $p->child($path);
                    if ( defined $d && -d $d && -r $d ) {
                        $base = $d;
                        return \0;
                    }
                }
            );
            last if defined $base;
        }
        $base // Carp::croak('Failed to find directory') unless $base;
    }
    sub sdldir { $base; }

    sub incdir {    # only valid in shared install
        sdldir->child('include');
    }

    sub libdir {    # only valid in shared dir
        sdldir->child('lib');
    }

    sub dynamic_libs {
        my $files = libdir->visit(
            sub {
                my ( $path, $state ) = @_;
                $state->{$path}++ if $path =~ m[\.$Config{so}([-\.][\d\.]+)?$];
            },
            { recurse => 1 }
        );
        keys %$files;
    }

    sub features ( $self, $feature //= () ) {
        CORE::state $config //= sub {
            my %h;
            my $section = '';
            for ( $base->child('.config')->lines ) {
                s/^\s+|\s+$//g;
                next if m/^;|^$/;
                if (m/^\[(.+)\]$/) { $section = $1 }
                elsif (m/^(.+?)\s*=\s*(.*)$/) { $h{$section}{$1} = $2 }
            }
            \%h;
            }
            ->();
        return $config->{$feature} if defined $feature;
        $config;
    }
}
1;

=encoding utf-8

=head1 NAME

Alien::SDL3 - Build and install SDL3

=head1 SYNOPSIS

    use Alien::SDL3; # Don't.

=head1 DESCRIPTION

Alien::SDL3 builds and installs L<SDL3|https://github.com/libsdl-org/SDL/>,
L<SDL2_image|https://github.com/libsdl-org/SDL_image/>, L<SDL2_mixer|https://github.com/libsdl-org/SDL_mixer/>, and
L<SDL2_ttf|https://github.com/libsdl-org/SDL_ttf/>. It is not meant for direct use. Just ignore it for now.

=head1 METHODS

=head2 C<dynamic_libs( )>

    my @libs = Alien::SDL3->dynamic_libs;

Returns a list of the dynamic library or shared object files.

=head1 Prerequisites

Prior to building and installing  on Linux and macOS systems, certain development dependencies must be present.

=head3 C<SDL3>

The X11 or Wayland development libraries are required on Linux, *BSD, etc.

=head3 C<SDL2_mixer>

These are required for building C<SDL2_mixer> for audio mixing support:

Linux (Debian/Ubuntu):

    $ sudo apt-get install libflac-dev libvorbis-dev libvorbisfile-dev libopus-dev

macOS (using Homebrew):

    $ brew install flac libvorbis opus

=head3 C<SDL2_image>

These are required for building C<SDL2_image> for image loading support:

Linux (Debian/Ubuntu):

    $ sudo apt-get install libpng-dev libjpeg-dev libwebp-dev

macOS (using Homebrew):

    $ brew install libpng jpeg-turbo libwebp

=head3 C<SDL2_ttf>

These are required for building C<SDL2_ttf> for TrueType font support:

Linux (Debian/Ubuntu):

    $ sudo apt-get install libfreetype-dev

macOS (using Homebrew):

    $ brew install freetype

=head1 LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2. Other copyrights, terms, and conditions may apply to data transmitted through this module.

=head1 AUTHOR

Sanko Robinson E<lt>sanko@cpan.orgE<gt>

=cut

