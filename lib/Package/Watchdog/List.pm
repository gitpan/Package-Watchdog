package Package::Watchdog::List;
use strict;
use warnings;
use Package::Watchdog::Util;

#{{{ POD

=pod

=head1 NAME

Package::Watchdog::List - List of packages and their subroutines.

=head1 DESCRIPTION

Used to maintain consistant lists of packages and subroutines for varying
purposes.

=item Will prevent duplicate sub listings.

=item Will note when all subs in a package should appear in the list

=item Generates list of subs from auto-collected( '*' ) and explicitly listed ones.

=head1 METHODS

=over 4

=cut

#}}}

=item $self = new( $package1 => $subs1, $package2 => $subs2, ... )

Create a new list.

=cut

sub new {
    my $class = shift;
    my %packages = @_;
    my $self = bless( {}, $class );

    for my $package ( keys %packages ) {
        $self->push( $package, $packages{ $package });
    }

    return $self;
}

=item push( $package, $subs )

Add $subs to the list under $package.

=cut

sub push {
    my $self = shift;
    my ( $package, $subs ) = @_;
    $subs ||= [ '*' ];
    $self->subs( $package, combine_subs( $self->_subs( $package ), $subs ));
    return $self;
}

=item $sublist = subs( $package )

Return the list of subs for $package.

=cut

sub subs {
    my $self = shift;
    my $package = shift;
    $self->{ $package } = shift( @_ ) if @_;
    return expand_subs( $package, $self->{ $package } );
}

=item @list = packages()

Returns the names of all the packages in the list.

=cut

sub packages {
    my $self = shift;
    return keys %$self;
}

=item clear()

Empty the list.

=cut

sub clear {
    my $self = shift;
    delete $self->{ $_ } for ( $self->packages );
    return $self;
}

=item merge_in( $lista, $listb, ... )

Merge in all the packages and subs from the specified lists into this list.

=cut

sub merge_in {
    my $self = shift;
    $self->_merge_in( $_ ) for @_;
    return $self;
}

=item _merge_in( $list )

Used by merge_in().

like merge_in() except only takes one list.

=cut

sub _merge_in {
    my $self = shift;
    my ( $other ) = @_;
    $self->push( $_, $other->_subs( $_ )) for $other->packages;
}

=item _subs( $package )

Same as subs() except that '*' is not expanded to all subs in package.

=cut

sub _subs {
    my $self = shift;
    my $package = shift;
    return undef unless exists $self->{ $package };
    return $self->{ $package } if $self->{ $package } and @{$self->{ $package }};
    return [ '*' ];
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
