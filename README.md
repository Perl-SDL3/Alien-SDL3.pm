# NAME

Alien::SDL3 - Build and install SDL3

# SYNOPSIS

```perl
use Alien::SDL3; # Don't.
```

# DESCRIPTION

Alien::SDL3 builds and installs [SDL3](https://github.com/libsdl-org/SDL/),
[SDL2\_image](https://github.com/libsdl-org/SDL_image/), [SDL2\_mixer](https://github.com/libsdl-org/SDL_mixer/), and
[SDL2\_ttf](https://github.com/libsdl-org/SDL_ttf/). It is not meant for direct use. Just ignore it for now.

# METHODS

## `dynamic_libs( )`

```perl
my @libs = Alien::SDL3->dynamic_libs;
```

Returns a list of the dynamic library or shared object files.

# Prerequisites

Prior to building and installing  on Linux and macOS systems, certain development dependencies must be present.

### `SDL3`

The X11 or Wayland development libraries are required on Linux, \*BSD, etc.

### `SDL2_mixer`

These are required for building `SDL2_mixer` for audio mixing support:

Linux (Debian/Ubuntu):

```
$ sudo apt-get install libflac-dev libvorbis-dev libvorbisfile-dev libopus-dev
```

macOS (using Homebrew):

```
$ brew install flac libvorbis opus
```

### `SDL2_image`

These are required for building `SDL2_image` for image loading support:

Linux (Debian/Ubuntu):

```
$ sudo apt-get install libpng-dev libjpeg-dev libwebp-dev
```

macOS (using Homebrew):

```
$ brew install libpng jpeg-turbo libwebp
```

### `SDL2_ttf`

These are required for building `SDL2_ttf` for TrueType font support:

Linux (Debian/Ubuntu):

```
$ sudo apt-get install libfreetype-dev
```

macOS (using Homebrew):

```
$ brew install freetype
```

# LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2\. Other copyrights, terms, and conditions may apply to data transmitted through this module.

# AUTHOR

Sanko Robinson <sanko@cpan.org>
