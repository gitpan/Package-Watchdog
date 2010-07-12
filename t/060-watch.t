#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Warn;

my $CLASS = 'Package::Watchdog::Tracker::Watch';

{
    package Fake;
    use strict;
    use warnings;

    sub a { 'a' }
    sub b { 'b' }
}

use_ok( $CLASS );
can_ok( $CLASS, qw/subs package react name/ );

dies_ok { $CLASS->new() } 'Must specify a package to track';
like( $@, qr/Must specify a package to track/, "Correct message" );

dies_ok { $CLASS->new( package => 'fake' ) } 'Must provide a reference to the stack';
like( $@, qr/Must provide a reference to the stack/, "Correct message" );

dies_ok {
    $CLASS->new(
        package => 'fake',
        stack => [],
        react => 'xxx'
    )
} 'Param \'react\' must be either \'die\', \'warn\', or a coderef.';
like( $@, qr/Param 'react' must be either 'die', 'warn', or a coderef./, "Correct message" );

my $one = $CLASS->new(
    package => 'Fake',
    stack   => [],
);

is( $one->react, 'die', "Default react is die" );
is_deeply( $one->subs, [ 'a', 'b' ], "all subs for Fake package");
is( $one->package, 'Fake', "Saved package" );

$one = $CLASS->new(
    package => 'My::Package',
    subs => [ 'a', 'b' ],
    stack => [],
    react => 'die',
);

is( $one->name, 'My::Package[a,b]=die', "Somewhat useful name generated" );

{
    package Fake::Forbidden;
    use strict;
    use warnings;

    sub new { bless( {}, shift (@_ ) ) }
    sub sub { 'ForbiddenSub' }
    sub package { 'Forbidden::Package' }

    package Fake::Forbid;
    use strict;
    use warnings;

    sub new { bless( {}, shift (@_ ) ) }
    sub watched { Fake::Watched->new }
    sub params {{watched_params => [ 'a' .. 'z' ]}}

    package Fake::Watched;
    use strict;
    use warnings;

    sub new { bless( {}, shift (@_ ) ) }
    sub sub { 'WatchedSub' }
    sub package { 'Watched::Package' }
}

is(
    $one->gen_warning({
        forbidden => Fake::Forbidden->new,
        forbid => Fake::Forbid->new,
        watched => Fake::Watched->new,
    }),
    'Watchdog warning: sub Forbidden::Package::ForbiddenSub was called from within Watched::Package::WatchedSub - '
        . $one->name,
    "Generated useful warning",
);

is(
    $one->gen_warning(
        {
            forbidden => Fake::Forbidden->new,
            forbid => Fake::Forbid->new,
            watched => Fake::Watched->new,
        },
        'fatal'
    ),
    'Watchdog fatal: sub Forbidden::Package::ForbiddenSub was called from within Watched::Package::WatchedSub - '
        . $one->name,
    "Generated useful warning - leveled",
);


warnings_like {
    $one->warn({
        forbidden => Fake::Forbidden->new,
        forbid => Fake::Forbid->new,
        watched => Fake::Watched->new,
    })
}   [ qr/Watchdog warning: sub Forbidden::Package::ForbiddenSub was called from within Watched::Package::WatchedSub/ ],
    "warns properly";

my %params;

$one = $CLASS->new(
    package => 'My::Package',
    subs => [ 'a', 'b' ],
    react => sub { %params = @_ },
    stack => [],
);

my $tmp = Fake::Forbid->new();

$one->do_react( forbid => $tmp, x => 'x', y => 'y' );

is_deeply(
    \%params,
    {
        forbid => $tmp,
        x => 'x',
        y => 'y',
    },
    "Proper params are passed to react sub"
);

done_testing;
