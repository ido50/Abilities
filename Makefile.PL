use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Abilities',
    AUTHOR              => q{Ido Perlmuter <ido@ido50.net>},
    VERSION_FROM        => 'lib/Abilities.pm',
    ABSTRACT_FROM       => 'lib/Abilities.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'base' => 2.14,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Abilities-*' },
);
