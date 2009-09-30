package Package::Watchdog::Tracker::Forbid;
use strict;
use warnings;
use Package::Watchdog::Util;
use Package::Watchdog::Sub::Forbidden;
use base 'Package::Watchdog::Tracker';

#{{{ POD

=pod

=head1 NAME

Package::Watchdog::Tracker::Forbid - Track forbidden subs.

=head1 DESCRIPTION

See Package::Watchdog::Tracker() for more information.

Used to track Package::Watchdog::Sub::Forbidden objects.

=head1 ACCESSORS

The following accessors methods are automatically generated using
Package::Watchdog::Util::build_accessors().

=over 4

=item params()

Arrayref of parameters passed to the watched sub that was called causing this
object to come into existance.

=item watched()

The Package::Watchdog::Sub::Watched that is responsible for this objects
existance.

=back

=head1 METHODS

=over 4

=cut

#}}}

my @ACCESSORS = qw/params watched/;
build_accessors( @ACCESSORS );

=item init( $self, $watched, $params )

new() should be called with $watched and $params appended to the end of the
argument list. This method is called by new to construct the object.

=cut

sub init {
    my $self = shift;
    my ( $watched, $params, $override_protos ) = @_;

    $self->watched( $watched );
    $self->params( $params );
    $self->override_protos( $override_protos );

    return $self;
}

=item track()

Forbid all the subs that should be forbidden according to the list in
$self->watched.

=cut

sub track {
    my $self = shift;

    my $forbid = Package::Watchdog::List->new();
    $forbid->merge_in( $_->forbid ) for @{ $self->watched->trackers };
    $self->forbid_subs( $_, $forbid->subs( $_ )) for $forbid->packages();

    return $self;
}

=item forbid_subs( $package, $subs )

Forbid the specified subs in the specified package.

=cut

sub forbid_subs {
    my $self = shift;
    my ( $package, $subs ) = @_;
    $self->forbid_sub( $package, $_ ) for @$subs;
    return $self;
}

=item forbid_sub( $package, $sub )

Forbid the specified sub in the specified package.

=cut

sub forbid_sub {
    my $self = shift;
    my ( $package, $sub ) = @_;

    my $forbidden = Package::Watchdog::Sub::Forbidden->new( $package, $sub, $self );

    push @{ $self->tracked } => $forbidden if $forbidden;

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
