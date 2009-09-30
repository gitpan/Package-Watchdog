package Package::Watchdog::Util;
use strict;
use warnings;
use base 'Exporter';

#{{{ POD

=pod

=head1 NAME

Package::Watchdog::Util - Utility functions for use within Package::Watchdog objects.

=head1 DESCRIPTION

Collection of utility functions. All functions in the package are exported.

=head1 FUNCTIONS

=over 4

=cut

#}}}

# Use the get_all_subs function to list all functions as exportable.
our @EXPORT = get_all_subs( __PACKAGE__ );

=item build_accessors( @ACCESSOR_LIST )

Create an accessor method for each accessor name passed in. Accessors store and
retrieve data from $self->{ $accessor }. Determines which package the accessors
should be added to via caller().

=cut

sub build_accessors {
    my ( $package ) = caller();
    for my $accessor ( @_ ) {
        my $ref = $package . '::' . $accessor;
        {
            no strict 'refs';
            *{ $ref } = sub {
                my $self = shift;
                $self->{ $accessor } = shift( @_ ) if @_;
                return $self->{ $accessor };
            }
        };
    }
}

=item expand_subs( $package, $subs )

Takes a package and list of subs, if the list is empty or undefined than all
subs in the package will be returned. If the list contains '*' then the return
will be all the susb in the list in addition to all the subs in the package.

Note: All subs in a package does not include inherited subs.

=cut

sub expand_subs {
    my ( $package, $subs ) = @_;

    return [ get_all_subs( $package ) ] unless $subs and @$subs;
    return $subs unless ( grep { $_ eq '*' } @$subs );

    my $listed = [ grep { $_ ne '*' } @$subs ];
    my $discovered = [ get_all_subs( $package )];

    return combine_subs( $listed, $discovered );
}

=item $subs = combine_subs( $setA, $setB )

Combine 2 arrayrefs of sub names into one arrayref containign entirely unique
items.

=cut

sub combine_subs {
    my ( $setA, $setB ) = @_;
    my %combined = map { $_ => 1 } @$setA, @$setB;
    return [ keys %combined ];
}

=item @list = get_all_subs( $package )

Returns all the sub names in the package.

=cut

sub get_all_subs {
    my ( $package ) = @_;
    $package = $package . '::' unless $package =~ m/::$/;
    {
        no strict 'refs';
        return grep { defined( *{$package . $_}{CODE} )} keys %$package;
    }
}

=item %subs = copy_subs( $package, $subs )

Get references to all the specified subs in the specified package.

$subs must be specified, it will not default to all susb in package.

return datastructure:

    %subs = (
        name => ref,
        ...
    );

=cut

sub copy_subs {
    my ( $pkg, $subs ) = @_;
    return map { $_ => copy_sub($pkg, $_) } @$subs;
}

=item $ref = copy_sub( $package, $sub )

Get the coderef for the specified sub in the specified package. If the sub is
inherited, a ref to it will still be returned.

=cut

sub copy_sub {
    my ( $pkg, $sub ) = @_;
    no strict 'refs';
    $pkg =~ s/\:\:$//g;
    return $pkg->can( $sub );
}

=item set_sub( $package, $sub, $new )

$new should be a coderef.

If $new is undef or omitted, the specified sub will be deleted from the
package.

=cut

sub set_sub {
    my ( $package, $sub, $new ) = @_;
    $package = $package . '::' unless $package =~ m/::$/;
    no strict 'refs';
    no warnings 'redefine';
    no warnings 'prototype';
    if ( $new ) {
        *{$package . $sub} = $new;
    }
    else {
        undef( &{$package . $sub});
    }
}

sub proper_return {
    my ( $want, $sub, @params ) = @_;

    if ( $want ) {
        my @array = $sub->( @params );
        return @array;
    }
    elsif( defined( $want )) {
        my $scalar = $sub->( @params );
        return $scalar;
    }

    $sub->( @params );
    return;
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
