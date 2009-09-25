package Package::Watchdog::Tracker::Watch;
use strict;
use warnings;
use Carp;
use Package::Watchdog::Util;
use Package::Watchdog::Sub::Watched;
use base 'Package::Watchdog::Tracker';

#{{{ POD

=pod

=head1 NAME

Package::Watchdog::Tracker::Watch - Tracker to track watched subs.

=head1 DESCRIPTION

Tracks Package::Watchdog::Sub::Watched objects.

=head1 ACCESSORS

The following accessors methods are automatically generated using
Package::Watchdog::Util::build_accessors().

=over 4

=item package()

The package being watched.

=item forbid()

Package::Watchdog::List object containing a list of packages and subs that
should be forbidden to the package.

=item react()

The default reaction when a forbidden sub is accessed.

=item name()

The name of this watch.

=back

=head1 METHODS

=over 4

=cut

#}}}

my @ACCESSORS = qw/package forbid react name/;
build_accessors( @ACCESSORS );

=item init( package => $package, forbid => $forbid, react => $react, subs => $subs )

Called by new(), arguments should be appended to the end of the arguments used w/ new().

package is the only mandatory argument, all others have defaults.

=cut

sub init {
    my $self = shift;
    my %params = @_;

    my ( $package, $forbid, $react, $subs ) = @params{@ACCESSORS};
    croak( "Must specify a package to watch" )
        unless $package;
    croak( "Must provide a Package\::Watchdog\::List for param 'forbid'" )
        unless $forbid and $forbid->isa( 'Package::Watchdog::List' );
    croak( "Param 'react' must be either 'die', 'warn', or a coderef." )
        unless !$react || ( grep { /^$react$/ } qw/warn die/ ) || ref $react eq 'CODE';

    $self->$_( $params{ $_ } ) for @ACCESSORS, 'subs';
    $self->subs( [ '*' ] ) unless $self->subs;
    $self->react( 'die' ) unless $self->react;
    $self->gen_name unless $self->name;

    return $self;
}

=item subs()

Returns the list of all subs that should be watched.

=cut

sub subs {
    my $self = shift;
    $self->{ subs } = shift( @_ ) if @_;
    return expand_subs( $self->package, $self->{ subs } );
}

=item gen_name()

Generates a name for the watch. Called by init() when name is not specified.

=cut

sub gen_name {
    my $self = shift;

    my $name = $self->package
             . '['
                . join(',', @{ $self->subs })
             . ']-['
                . join(',', $self->forbid->packages)
             . "]=" . $self->react;

    $self->name( $name );
    return $self;
}

=item track()

Starts watching the specified subs.

=cut

sub track {
    my $self = shift;
    $self->watch_sub( $_ ) for @{ expand_subs( $self->package, $self->subs )};
    return $self;
}

=item watch_sub( $sub )

Watch a specific sub in the watch's package.

=cut

sub watch_sub {
    my $self = shift;
    my ( $sub ) = @_;
    my $watched = Package::Watchdog::Sub::Watched->new( $self->package, $sub, $self );
    push @{ $self->tracked } => $watched unless grep { $_ == $watched } @{ $self->tracked };
    return $self;
}

=item gen_warning( $set, $level )

FOR INTERNAL USE ONLY

Generates the warning message when a watch is violated.

=cut

sub gen_warning {
    my $self = shift;
    my ( $set, $level ) = @_;
    my $forbidden = $set->{ forbidden };
    my $watched = $set->{ forbid }->watched;

    $level ||= 'warning';

    return "Watchdog $level: sub "
           . $forbidden->package . "::" . $forbidden->sub
           . " was called from within " 
           . $watched->package . '::' . $watched->sub
           . " - " . $self->name;
}

=item warn( $set, $level )

FOR INTERNAL USE ONLY

Issue a warning when a watch is violated.

=cut

sub warn {
    my $self = shift;
    warn( $self->gen_warning( @_ ));
    return $self;
}

=item do_react( %params )

FOR INTERNAL USE ONLY

Runs the custom reaction code when a watch is violated.

=cut

sub do_react {
    my $self = shift;
    my %params = @_;
    my $forbid = $params{forbid};

    $self->react->(
        @_,
        watch => $self,
        watched => $forbid->watched,
        watched_params => $forbid->params,
    );
    return $self;
}

1;

__END__

=back

=head1 AUTHORS

=over 4

=item Chad Granum L<chad@opensourcery.com>

=back

=head1 COPYRIGHT

Copyright (C) 2009 OpenSourcery, LLC

Package-Watchdog is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option) any
later version.

Package-Watchdog is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
Street, Fifth Floor, Boston, MA 02110-1301 USA.

Package-Watchdog is packaged with a copy of the GNU General Public License.
Please see docs/COPYING in this distribution.
