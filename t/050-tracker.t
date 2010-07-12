#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception;

my $CLASS = 'Package::Watchdog::Tracker';

use_ok( $CLASS );

done_testing;
