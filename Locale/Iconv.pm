#! /bin/false
# -*- perl -*-

# Iconv interface for Perl.
# Copyright (C) 2002 Guido Flohr <guido@imperia.net>, all rights reserved.

# Distribution either under the terms of the Artistic license (see
# Artistic) or - at your choice - under the terms and conditions of
# the GNU General Public License described below.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA.

package Locale::Iconv;

use strict;

require Locale::Iconv::_Aliases;
require Locale::Iconv::_Conversions;

use vars qw ($VERSION);

$VERSION = '0.02';

my $loaded = {};

sub new
{
    my $class = ref($_[0]) || $_[0];
    shift;
    my %args = @_;

    my $self = bless {}, $class;

    my ($from_codeset, $to_codeset,
	$unknown, $illegal) = @args{qw (from to unknown illegal)};
    
    unless ($from_codeset && $to_codeset) {
	require Carp;
        Carp::croak (<<EOF);
Usage: $class->new (from => FROM_CODESET, to => TO_CODESET);
EOF
    }

    $unknown = ord '?' unless exists $args{unknown};
    $illegal = $unknown unless exists $args{illegal};

    # Canonicalize codesets.
    $from_codeset = uc $from_codeset;
    $to_codeset = uc $to_codeset;
    # Resolve aliases.
    $from_codeset = Locale::Iconv::_Aliases::ALIASES()->{$from_codeset} if
	exists Locale::Iconv::_Aliases::ALIASES()->{$from_codeset};
    $to_codeset = Locale::Iconv::_Aliases::ALIASES()->{$to_codeset} if
	exists Locale::Iconv::_Aliases::ALIASES()->{$to_codeset};
    $from_codeset .= '//' unless 'INTERNAL' eq $from_codeset;
    $to_codeset .= '//' unless 'INTERNAL' eq $to_codeset;

    # Find a conversion path.
    my @path = ();
    unless ($from_codeset eq $to_codeset) {
	my $start = Locale::Iconv::_Conversions::CONVERSIONS()->{$from_codeset};

	unless (defined $start) {
	    $self->{__error} = 'EINVAL';
	    return $self;
	}

	my $intermediate = $start->{$to_codeset};
	if (defined $intermediate) {
	    # We have an immediate conversion.
	    push @path, [ $intermediate, $from_codeset, $to_codeset ];
	} else {
	    $intermediate = $start->{INTERNAL};
	    unless (defined $intermediate) {
		# Oops, not even an entry for INTERNAL.
		$self->{__error} = 'EINVAL';
		return $self;
	    }
	    push @path, [ $intermediate, $from_codeset, 'INTERNAL' ];

	    my $from_internal = 
	      Locale::Iconv::_Conversions::CONVERSIONS()->{INTERNAL};

	    unless (defined $from_internal) {
		# Oops ...
		$self->{__error} = 'EINVAL';
		return $self;
	    }

	    my $end = $from_internal->{$to_codeset};
	    unless (defined $end) {
		$self->{__error} = 'EINVAL';
		return $self;
	    }

	    push @path, [ $end, INTERNAL => $to_codeset ];
	}
    }

    my @conversions = ();
    foreach (@path) {
	my ($module, $from, $to) = @$_;

	unless ($loaded->{$module}) {
	    eval "require Locale::IconvData::$module";
	    if ($@) {
		$self->{__error} = $@;
		return $self;
	    }

	    $loaded->{$module} = 1;
	}
	
	my $module_name = "Locale::IconvData::$module";
	my $method = 'new';
	my $object = $module_name->$method (from => $from,
					    to => $to,
					    illegal => $illegal,
					    unknown => $unknown);

	push @conversions, $object;
    }

    $self->{__conversions} = \@conversions;

    return $self;
}

sub recode
{
    my $self = $_[0];

    return if $self->{__error};

    return 1 unless defined $_[1];

    my $chain = $self->{__conversions};
    
    foreach my $module (@$chain) {
	my $success = $module->_recode ($_[1]);

	unless ($success) {
	    $self->{__error} = $module->_getError;
	    return;
	}
    }

    return 1;
}

sub getError
{
    my $self = shift;
    my $error = $self->{__error} or return;

    if ('EINVAL' eq $error) {
	return 'Invalid conversion';
    } else {
	return $error;
    }
}

1;

__END__

Local Variables:
mode: perl
perl-indent-level: 4
perl-continued-statement-offset: 4
perl-continued-brace-offset: 0
perl-brace-offset: -4
perl-brace-imaginary-offset: 0
perl-label-offset: -4
cperl-indent-level: 4
cperl-continued-statement-offset: 2
tab-width: 4
End:

=head1 NAME

Locale::Iconv

=head1 SYNOPSIS

use Locale::Iconv qw (iconv_open iconv iconv_close recode);

$cd = Locale::Iconv->new (from => 'UTF-8',
                          to   => 'ISO-8859-1',
                          unknown => chr '?',
                          illegal => chr '?',
                         );

die $cd->getError if $cd->getError;

$cd->recode ($text) or
    die $cd->getError;

$irreversible = $cd->iconv ($text, $inbytes_left,
                            $converted, $outbytes_left);

die $cd->getError if $cd->getError;

$cd = iconv_open ('ISO-8859-1', 'UTF-8');

recode ($cd, $text) or
    die $Locale::Iconv::getError();

$irreversible = iconv ($cd, $text, $inbytes_left, 
                       $converted, $outbytes_left);

die $Locale::Iconv::getError() if $irreversible == -1;

iconv_close ($cd);

=head1 DESCRIPTION

This module provides routines that convert textual data from one
codeset to another.  

=head1 AUTHOR

Copyright (C) 2002, Guido Flohr E<lt>guido@imperia.netE<gt>, all
rights reserved.  See the source code for details.

This software is contributed to the Perl community by Imperia 
(http://www.imperia.net/).

=head1 SEE ALSO

iconv(3), iconv(1), perl(1)

