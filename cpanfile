requires 'perl', '5.024000';
requires 'Path::Tiny';
requires 'File::ShareDir';
on 'test' => sub {
    requires 'Test2::V0';
};
on configure => sub {
    requires 'HTTP::Tiny';
    requires 'IO::Socket::SSL', '1.42';
    requires 'Net::SSLeay',     '1.49';
    requires 'Path::Tiny';
    requires 'Archive::Extract', '0.88';
    requires 'Archive::Tar',     '3.02';
    requires 'Archive::Zip';    # Win32
    requires 'Compress::Zlib', '2.204';
    requires 'IO::Zlib',       '1.14';
    requires 'ExtUtils::CBuilder';
    requires 'Alien::cmake3';
    requires 'Module::Build';
    requires 'Devel::CheckBin';
};
on 'develop' => sub {
    requires 'Software::License::Artistic_2_0';
    recommends 'Perl::Tidy';
    recommends 'Pod::Tidy';
    recommends 'Code::TidyAll::Plugin::PodTidy';
    recommends 'Code::TidyAll';
    requires 'Pod::Markdown::Github';
    recommends 'Test::Pod';
    recommends 'Test::PAUSE::Permissions';
    recommends 'Test::MinimumVersion::Fast';
    recommends 'Test::CPAN::Meta';
    recommends 'Test::Spellunker';
    requires 'Minilla';
    recommends 'Data::Dump';
    requires 'Version::Next';
    requires 'CPAN::Uploader';
};
