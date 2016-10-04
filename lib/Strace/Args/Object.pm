package Strace::Args::Object;

# This module is a representation of binary flag lists (ie: O_WRONLY|O_TRUNC|O|WHTEVR

use overload
	# String convertion
	'""' => sub { return "{".join(', ',map { "'$_': $_[0]{$_}" } keys %{$_[0]})."}" };


# Constructor
sub new {
	my $class = shift;

	return bless $_[0]||{}, $class;
}

1;
