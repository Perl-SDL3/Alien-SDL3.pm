requires 'perl', '5.024000';
requires 'Path::Tiny';
requires 'File::ShareDir';
on 'test' => sub {
    requires 'Test::More', '0.98';
};
on configure => sub {
    requires 'HTTP::Tiny';
    requires 'Path::Tiny';
    requires 'Archive::Extract';
    #
    requires 'ExtUtils::CBuilder';
    requires 'Alien::gmake';
    requires 'Alien::cmake3';

    #~ requires 'Alien::Ninja';
    requires 'Module::Build';
    requires 'Devel::CheckBin';
};
