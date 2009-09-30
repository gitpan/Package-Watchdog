#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 30;
use Test::Exception;
use Package::Watchdog::Util;

my $CLASS = 'Package::Watchdog::Sub';

use_ok( $CLASS );

can_ok( $CLASS, qw/package sub original/ );

{
    package Test::Sub;
    use strict;
    use warnings;
    use base 'Package::Watchdog::Sub';

    sub new_sub {
        return sub { 'x' };
    }

    sub init {
        my $self = shift;
        my $param = shift;
        main::is( $param, 'param', "init got extra params" );
    };

    ##############
    package Test::Package;
    use strict;
    use warnings;

    sub a { 'a' }
    sub b { 'b' }
    sub c { 'c' }
    sub array { qw/a b c/ }
    sub fatal { die("I died") }
}

dies_ok { $CLASS->new_sub } "Must override new_sub";

is( Test::Package->a, 'a', "Original" );

isa_ok( my $one = Test::Sub->new( 'Test::Package', 'a', ['Tracker'], 'param' ), $CLASS );
is( $one, Test::Sub->new( 'Test::Package', 'a', ['Tracker'], 'param' ), "Only one instance per class/package/sub" );

is( Test::Package->a, 'x', "Overriden" );

$one->restore;

is( Test::Package->a, 'a', "Restored" );

ok( $one != Test::Sub->new( 'Test::Package', 'a', ['Tracker'], 'param' ), "Old instance destroyed" );

is( Test::Package->a, 'x', "Overriden again" );

Test::Sub->new( 'Test::Package', 'a', ['Tracker'], 'param' )->restore();
is( Test::Package->a, 'a', "Restored" );

dies_ok { $one->do_override() } "Cannot do_override on expired object";

Test::Sub->new( 'Test::Package', 'a', ['Tracker'], 'param' );
dies_ok { $one->do_override() } "Cannot do_override on expired object";

Test::Sub->new( 'Test::Package', 'a', ['Tracker'], 'param' )->restore;
is( Test::Package->a, 'a', "Restored" );

{
    no warnings 'redefine';
    *Test::Sub::init = sub { 1 };
}

my $original = copy_sub( 'Test::Package', 'a' );
$one = Test::Sub->new( 'Test::Package', 'a', ['TrackA'] );
ok( \&Test::Package::a != $original, "replaced" );
my $two = Test::Sub->new( 'Test::Package', 'a', ['TrackB'] );
ok( \&Test::Package::a != $original, "Still replaced" );

is( $one, $two, "Only one instance of a sub override" );
is_deeply( $one->trackers, [ ['TrackA'], ['TrackB'] ], "Correct Tracks" );

$one->remove_tracker( $one->trackers->[0] );
is_deeply( $one->trackers, [ ['TrackB'] ], "Correct Tracks" );
ok( \&Test::Package::a != $original, "Still replaced" );

$one->remove_tracker( $one->trackers->[0] );
is_deeply( $one->trackers, [ ], "Correct Tracks" );
ok( \&Test::Package::a == $original, "Restored" );

{
    package My::WantArray;
    use strict;
    use warnings;

    sub what_we_want {
        my $self = shift;
        my $want = wantarray();
        return split( '', 'Want Array' ) if $want;
        return 'Scalar' if defined( $want );
        return;
    }

    package My::Test::Want;
    use strict;
    use warnings;
    use Package::Watchdog::Util;

    use base 'Package::Watchdog::Sub';

    our $RAN = 0;

    sub new_sub {
        my $self = shift;
        return sub {
            $RAN++;
            my $want = wantarray();
            return proper_return( $want, $self->original, @_ );
        };
    }
}

my $tmp = My::Test::Want->new( 'My::WantArray', 'what_we_want' );

my @array = My::WantArray->what_we_want;

is_deeply(
    \@array,
    [ split( '', 'Want Array' )],
    'Wanted an array'
);

my $scalar = My::WantArray->what_we_want;

is_deeply(
    $scalar,
    'Scalar',
    'Wanted a scalar'
);
