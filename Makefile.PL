#!/usr/bin/env perl
use strict;
use warnings;
use inc::Module::Install;

perl_version '5.008';
license 'gpl';
all_from 'lib/Package/Watchdog.pm';


requires (
    Carp => 0,
);

test_requires (
    'Test::More' => 0,
    'Test::Exception' => 0,
);

if ($Module::Install::AUTHOR) {
    system("pod2text lib/Package/Watchdog.pm > README")
        and die;
}

WriteAll;

