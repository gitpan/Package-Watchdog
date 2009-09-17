#!/usr/bin/env perl
use strict;
use warnings;
use inc::Module::Install;

name 'package-watchdog';
all_from 'lib/Package/Watchdog.pm';
license 'gpl';

WriteAll;

