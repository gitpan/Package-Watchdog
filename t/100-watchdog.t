#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Warn;

my $CLASS = 'Package::Watchdog';
our @STACK;

use_ok( $CLASS );

my $one = $CLASS->new();

is_deeply(
    $one->watches,
    [],
    "No Watches by default"
);
is_deeply(
    $one->forbids,
    [],
    "No Forbids by default"
);

is( $one->react, 'die', 'default react is die' );

my $tmp = sub { 1 };
$one = $CLASS->new( $tmp );
is( $one->react, $tmp, "Custom reaction" );

{
    package My::Package;
    use strict;
    use warnings;

    sub a { 'a' };
    sub b { 'b' };
    sub c { 'c' };

    package My::WatchA;
    use strict;
    use warnings;

    sub a {
        My::Package::a()
    };
    sub b { My::Package::a() };
    sub c { My::Package::a() };
    sub d { My::Package::d() };

    package My::WatchB;
    use strict;
    use warnings;

    sub a { My::Package::a() };
    sub b { My::Package::a() };
    sub c { My::Package::a() };
}

$one->stack( \@STACK );
$one->forbid( 'My::Package' ) #All subs
    ->forbid( 'Another::Package', [ 'a' ] ); #Specific sub

is( @{$one->forbids}, 2, "Correct forbids" );

$one->react( 'die' );
$one->watch( package => 'My::WatchA' )
    ->watch( package => 'My::WatchB', subs => [ 'a' ]);

{
    no warnings qw/once redefine/;
    local $SIG{ __WARN__ } = sub {};
    local *Package::Watchdog::Sub::restore = sub {1};
    dies_ok { My::WatchA::a() } 'Watched sub a';
    dies_ok { My::WatchA::a() } 'Still watching sub a';
    dies_ok { My::WatchA::b() } 'Watched sub b';
    dies_ok { My::WatchA::c() } 'Watched sub c';

    dies_ok  { My::WatchB::a() } 'Watched sub a';
    lives_ok { My::WatchB::b() } 'not watching sub b';
    lives_ok { My::WatchB::c() } 'not watching sub c';
}

$one = undef;

lives_ok { My::WatchA::a() } 'destroyed watchdog: sub a';
lives_ok { My::WatchA::b() } 'destroyed watchdog: sub b';
lives_ok { My::WatchA::c() } 'destroyed watchdog: sub c';
lives_ok { My::WatchB::a() } 'destroyed watchdog: sub a';

$one = $CLASS->new( 'warn' );
$one->watch( package => 'My::WatchA', name => 'watch a' )
    ->watch( package => 'My::WatchB', subs => [ 'a' ], name => 'watch b')
    ->watch( package => 'My::WatchA', subs => [ 'a' ], name => 'watch c')
    ->forbid( 'My::Package' ) #All subs
    ->forbid( 'Another::Package', [ 'a' ] ); #Specific sub

warnings_like { My::WatchA::a() }
    [
        qr/Watchdog warning: sub My::Package::a was called from within My::WatchA::a - watch a/,
    ],
    'Watched sub a';

warnings_like { My::WatchA::b() }
    [ qr/Watchdog warning: sub My::Package::a was called from within My::WatchA::b - watch a/ ],
    'Watched sub b';

warnings_like { My::WatchA::c() }
    [ qr/Watchdog warning: sub My::Package::a was called from within My::WatchA::c - watch a/ ],
    'Watched sub c';

warnings_like { My::WatchB::a() }
    [ qr/Watchdog warning: sub My::Package::a was called from within My::WatchB::a - watch b/ ],
    'Watched sub a';

$one->kill;

warnings_like { My::WatchA::a() }
    [],
    'no warnings for sub a';

warnings_like { My::WatchA::b() }
    [],
    'no warnings for sub b';

warnings_like { My::WatchA::c() }
    [],
    'no warnings for sub c';

warnings_like { My::WatchB::a() }
    [],
    'no warnings for sub a';

done_testing;
