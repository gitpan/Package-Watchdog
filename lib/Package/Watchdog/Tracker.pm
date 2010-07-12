package Package::Watchdog::Tracker;
use strict;
use warnings;
use Carp;
use Package::Watchdog::Util;

#{{{ POD

=pod

=head1 NAME

Package::Watchdog::Tracker - Base class for objects that track overriden subs.

=head1 DESCRIPTION

Base class for objects that track overriden subs.

=head1 ACCESSORS

The following accessors methods are automatically generated using
Package::Watchdog::Util::build_accessors().

=head1 METHODS

=over 4

=cut

#}}}

my @ACCESSORS = qw/package stack/;
build_accessors( @ACCESSORS );

=item track()

Starts tracking the specified subs.

=cut

sub track {
    my $self = shift;
    my %seen;
    for my $sub (@{ expand_subs( $self->package, $self->subs )}) {
        next if $seen{$sub}++;
        $self->track_sub( $sub )
    }
    return $self;
}

=item init( $self, @params )

Should be overriden by a subclass. Called by new after object construction.

=cut

sub init {
    my $self = shift;
    return $self;
}

=item new( @params )

All params are passed into init(). Creates a new instance of the tracker, also
runs track() to begin tracking subs..

=cut

sub new {
    my $class = shift;
    my %params = @_;

    my $self = bless({ tracked => [] }, $class );

    my ( $package, $stack, $subs ) = @params{(@ACCESSORS, 'subs')};
    croak( "Must specify a package to track" )
        unless $package;
    croak( "Must provide a reference to the stack" )
        unless $stack && ref( $stack ) eq 'ARRAY';

    $self->$_( $params{ $_ } ) for (@ACCESSORS, 'subs');
    $self->subs( [ '*' ] ) unless $self->subs;

    $self->init( %params );
    $self->track();

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
