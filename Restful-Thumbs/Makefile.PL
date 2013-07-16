use strict;
use warnings;
use ExtUtils::MakeMaker;

# Normalize version strings like 6.30_02 to 6.3002,
# so that we can do numerical comparisons on it.
my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

WriteMakefile(
    NAME                => 'Restful::Thumbs',
    AUTHOR              => q{YOUR NAME <youremail@example.com>},
    VERSION_FROM        => 'lib/Restful/Thumbs.pm',
    ABSTRACT            => 'YOUR APPLICATION ABSTRACT',
    ($eumm_version >= 6.3001
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'           => 0,
        'YAML'                 => 0,
        'Dancer'               => 1.3116,
        'Image::Grab'          => 0,  
        'GD'                   => 0,
        'Image::Resize'        => 0,
        'Image::Info'          => 0,
        'Dancer::Plugin::REST' => 0,
        'Dancer::Plugin::DBIC' => 0,
        'Dancer::Plugin::Database' => 0,
        'DBIx::Class::Schema::Loader' => 0,

    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Restful-Thumbs-*' },
);
