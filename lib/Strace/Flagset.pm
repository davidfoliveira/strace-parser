package Strace::Flagset;

# This module is a representation of binary flag lists (ie: O_WRONLY|O_TRUNC|O|WHTEVR

use overload
	# String convertion
	'""' => sub { return join('|',sort(flags(@_))) };


# Constructor
sub new {
	my $class = shift;

	my %flags;
	foreach my $str ( split(/\|/, join("|", @_)) ) {
		$flags{$str} = 1;
	}

	return bless [ keys %flags ], $class;
}

# Return an array of flags
sub flags {
	return @{$_[0]};
}

# Check if the flagset contains the supplied flag(s)
sub has {
	my $self = shift;

	return undef if !@_;

	foreach my $qFlag ( @_ ) {
		my $match = 0;
		foreach my $flag ( @{$self} ) {
			if ( uc($flag) eq uc($qFlag) ) {
				$match = 1;
				last;
			}
		}
		return 0 if !$match
	}

	return 1;
}

1;
