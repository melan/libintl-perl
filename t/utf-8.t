#! /usr/local/bin/perl -w

# vim: syntax=perl
# vim: tabstop=4

use strict;

use Test;

BEGIN {
	plan tests => 5;
}

use Locale::Iconv;

sub int2utf8;

my $codes = {};
foreach (0 .. 0x1_800, 
		 0x10_000 .. 0x11_000,
	     # 0x200_000 .. 0x201_000,      # :-(  # Not supported by Perl 5.6
	     # 0x4_000_000 .. 0x4_001_000,  # :-(  # Not supported by Perl 5.6
         ) {
	my $utf8 = int2utf8 $_;
	$codes->{$utf8} = $_;
}

my $cd_int = Locale::Iconv->new (from => 'UTF-8',
			     		  		 to => 'INTERNAL');
ok !$cd_int->getError;

my $cd_rev = Locale::Iconv->new (from => 'INTERNAL',
								 to => 'UTF-8');
ok !$cd_rev->getError;

# Convert into internal representation.
my $result_int = 1;
while (my ($outbuf, $ucs4) = each %$codes) {
	my $result = $cd_int->recode ($outbuf);
	unless ($result && $outbuf->[0] == $ucs4) {
		$result_int = 0;
		last;
	}
}
ok $result_int;

# Convert from internal representation.
my $result_rev = 1;
while (my ($code, $ucs4) = each %$codes) {
    my $outbuf = [ $ucs4 ];
    my $result = $cd_rev->recode ($outbuf);
    unless ($result && $code eq $outbuf) {
        $result_int = 0;
        last;
    }
}
ok $result_int;

# Check handling of unknown characters.  This assumes that the 
# character set is a subset of US-ASCII.
my $test_string1 = "\xffSupergirl\xff";
$cd_rev = Locale::Iconv->new (from => 'ASCII',
							   to => 'UTF-8',
							   unknown => 0x2a,  # Asterisk!
							  );
$result_rev = $cd_rev->recode ($test_string1);
ok $result_rev && $test_string1 eq "*Supergirl*";

sub int2utf8
{
    my $ucs4 = shift;

    if ($ucs4 <= 0x7f) {
		return chr $ucs4;
    } elsif ($ucs4 <= 0x7ff) {
		return pack ("c2", 
			(0xc0 | (($ucs4 >> 6) & 0x1f)),
			(0x80 | ($ucs4 & 0x3f)));
    } elsif ($ucs4 <= 0xffff) {
		return pack ("c3", 
			(0xe0 | (($ucs4 >> 12) & 0xf)),
			(0x80 | (($ucs4 >> 6) & 0x3f)),
			(0x80 | ($ucs4 & 0x3f)));
    } elsif ($ucs4 <= 0x1fffff) {
		return pack ("c4", 
			(0xf0 | (($ucs4 >> 18) & 0x7)),
			(0x80 | (($ucs4 >> 12) & 0x3f)),
			(0x80 | (($ucs4 >> 6) & 0x3f)),
			(0x80 | ($ucs4 & 0x3f)));
    } elsif ($ucs4 <= 0x3ffffff) {
		return pack ("c5", 
			(0xf0 | (($ucs4 >> 24) & 0x3)),
			(0x80 | (($ucs4 >> 18) & 0x3f)),
			(0x80 | (($ucs4 >> 12) & 0x3f)),
			(0x80 | (($ucs4 >> 6) & 0x3f)),
			(0x80 | ($ucs4 & 0x3f)));
    } else {
		return pack ("c6", 
			(0xf0 | (($ucs4 >> 30) & 0x3)),
			(0x80 | (($ucs4 >> 24) & 0x1)),
			(0x80 | (($ucs4 >> 18) & 0x3f)),
			(0x80 | (($ucs4 >> 12) & 0x3f)),
			(0x80 | (($ucs4 >> 6) & 0x3f)),
			(0x80 | ($ucs4 & 0x3f)));
    }
}

# Local Variables:
# mode: perl
# perl-indent-level: 4
# perl-continued-statement-offset: 4
# perl-continued-brace-offset: 0
# perl-brace-offset: -4
# perl-brace-imaginary-offset: 0
# perl-label-offset: -4
# cperl-indent-level: 4
# cperl-continued-statement-offset: 2
# tab-width: 4
# End:
