package Package::Watchdog;
use strict;
use warnings;
use Carp;

=pod

=head1 NAME

Package::Watchdog - Forbid subs in one package from accessing subs in another package, directly or otherwise.

=head1 DESCRIPTION

This package provides a function that allows you to 'watch' methods in a
package to ensure they do not access methods in another package. The watch
endures until the function returns meaning functions caleld by your package
cannot access the forbidden package's subs either.

You can also generate warnings when access occurs as opposed to dying. But
perhapse the most useful feature is a custom reaction subroutine.

=head1 SYNOPSYS

Don't let package My::Package access subs in Fake::Package (die if it tries)

    add_watchdog( watch => 'My::Package', forbid => 'Fake::Package' );

Warn instead

    add_watchdog( watch => 'My::Package', forbid => 'Fake::Package', warn => 1 );

Handle is a custom way

    add_watchdog( watch => 'My::Package', forbid => 'Fake::Package', react => sub { ... } );

See REACT below for more details on the REACT sub.


Watch only specific subs

    add_watchdog( watch => 'My::Package', forbid => 'Fake::Package', watch_subs => [ 'suba', 'subb' ] );

Forbid only specific subs

    add_watchdog( watch => 'My::Package', forbid => 'Fake::Package', forbid_subs => [ 'suba', 'subb' ] );

=head1 REACT SUBS

Here is an example of a reaction that dies when the watched sub is called with
no parameters, but continues as normal when the watched sub was called with a
parameter.

    react => sub {
        my %params = @_;
        if ( $params{ watch_params }->[0] ) {
            return $params{ original_sub }->( @{ $params{ forbid_params }} )
        }
        die( 'reacted badly' );
    }

%params contains the following:

    {
        watch => WATCHED PACKAGE NAME
        watch_params => [ @_ for the watched sub ]
        original_watch_sub => coderef for the original sub that was watched
        watched_sub => name of the sub that was watched

        forbid => FORBIDDEN PACKAGE NAME
        forbid_params => [ @_ for the forbidden sub ]
        original_sub => coderef for the original sub that was forbidden
        forbid_sub => name of the sub that was forbidden

        message => the typical watchdog die/warn message string
    }

=head1 Notes and Caveats

=over 4

=item AUTOLOAD and similar

You cannot watch a sub until it exists. If the sub is an AUTOLOAD function you
must AUTOLOAD it first.

You can forbid a sub that does not exist, however a custom react sub will not
have a reference to the original in such a case.

You can forbid access to an inherited method. Will work just like any other
method. However calling the method on the parent class is not forbidden.

=back

=head1 EXPORTED FUNCTIONS

=over 4

=cut

use base 'Exporter';

our @EXPORT = qw/add_watchdog/;
our @EXPORT_OK = all_subs_in_package( __PACKAGE__ );
our $VERSION = 0.01;

=item add_watchdog( watch => 'My::Package', forbid => 'Their::Package', ... )

See the synopsis. This is the only automatically exported function.

=cut

sub add_watchdog {
    my %params = @_;

    croak( "Parameter 'react' must be a coderef!\n" ) if ( $params{ react } and not ref $params{ react } eq 'CODE' );
    croak( "Minimum arguemtns are 'watch' and 'forbid'\n" ) unless ( $params{ watch } and $params{ forbid } );

    $params{ watch_subs } ||= [ all_subs_in_package($params{ watch }) ];

    croak( "$_ is not defined in package: $params{ watch }." ) for grep {
        my $sub = $_;
        ! grep { $_ eq $sub } all_subs_in_package($params{ watch })
    } @{ $params{ watch_subs }};

    $params{ 'warn' } = $params{ 'warn' };

    $params{ watch_pkg } = $params{ watch } . '::';
    $params{ forbid_pkg } = $params{ forbid } . '::';

    watch_sub( $_, %params ) for ( @{ $params{ watch_subs }} );
}

sub watch_sub {
    my ( $watched_sub_name, %params ) = @_;
    replace_sub(
        $params{ watch_pkg },
        $watched_sub_name,
        gen_watched_sub(
            $watched_sub_name,
            copy_original_sub( $params{ watch_pkg }, $watched_sub_name ),
            %params,
        )
    );
}

sub get_forbidden_subs {
    my ( %params ) = @_;
    my @forbid_subs = $params{forbid_subs} ? @{ $params{forbid_subs}}
                                           : all_subs_in_package($params{ forbid });

    # May want to forbid functions that lead back to a parent, plus all the
    # packages functions.
    push( @forbid_subs, all_subs_in_package($params{ forbid }))
        if ( $params{forbid_subs} and $params{forbid_all} );
    return @forbid_subs;
}

sub gen_watched_sub {
    my ( $watched_sub_name, $original_watched_sub, %params ) = @_;

    return sub {
        my @forbid_subs = get_forbidden_subs( %params );
        my ( $error, @return );

        my %original = copy_original_subs( $params{ forbid_pkg }, [ @forbid_subs ]);
        {
            no strict 'refs';
            local @{$params{ forbid_pkg }}{@forbid_subs}; #Thank you confound++
            {
                use strict 'refs';
                forbid_subs(
                    %params,
                    watch_params => [ @_ ],
                    original => \%original,
                    forbid_subs => \@forbid_subs,
                    watch_sub => $watched_sub_name,
                    original_watch_sub => $original_watched_sub,
                    watched_sub => $watched_sub_name,
                );

                @return = (eval { $original_watched_sub->( @_ )});
                $error = $@;
            }
        }
        die( $error ) if $error;
        return shift( @return ) unless wantarray();
        return @return if @return;
        return;
    };
}

sub forbid_subs {
    my ( %params ) = @_;
    my %original = $params{ original } ? %{ $params{original} }
                                       : copy_original_subs(
                                            $params{ forbid_pkg },
                                            $params{ forbid_subs }
                                         );
    for my $forbid_sub ( @{ $params{ forbid_subs }}) {
        my %react_params = map { $_ => $params{ $_ }} qw/
            watch watch_params original_watch_sub watched_sub forbid react
        /;

        replace_sub(
            $params{ forbid_pkg },
            $forbid_sub,
            sub { react( %react_params, original_sub => $original{$forbid_sub}, forbid_sub => $forbid_sub, forbid_params => [ @_ ])},
        )
    }
    return %original;
}

sub react {
    my %params = @_;
    my $message = join(
        '',
        "Watchdog: Attempted to use ",
        $params{ forbid }, '::', $params{ forbid_sub },
        " from within ",
        $params{ watch }, '::', $params{ watched_sub },
        "\n"
    );

    if ( $params{ react } ) {
        return $params{ react }->( %params, message => $message );
    }
    elsif ( $params{ 'warn' } ) {
        carp( $message );
        return;
    }
    croak( $message );
}

sub copy_original_subs {
    my ( $pkg, $subs ) = @_;
    return map { $_ => copy_original_sub($pkg, $_) } @$subs;
}

sub copy_original_sub {
    my ( $pkg, $sub ) = @_;
    no strict 'refs';
    $pkg =~ s/\:\:$//g;
    return $pkg->can( $sub );
#    return \&{$pkg . $sub};
}

sub all_subs_in_package {
    my ( $package ) = @_;
    $package = $package . '::' unless $package =~ m/::$/;
    {
        no strict 'refs';
        return grep { defined( *{$package . $_}{CODE} )} keys %$package;
    }
}

sub replace_sub {
    my ( $pkg, $sub, $code ) = @_;
    my $original = copy_original_sub( $pkg, $sub );
    {
        no warnings 'redefine';
        no strict 'refs';
        *{$pkg . $sub} = $code;
    }
    return $original;
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
