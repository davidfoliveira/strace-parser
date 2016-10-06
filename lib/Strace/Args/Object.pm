package Strace::Args::Object;

# This module is a representation of binary flag lists (ie: O_WRONLY|O_TRUNC|O|WHTEVR

use overload
	# String convertion
	'""' => sub { return "{".join(', ',map { "'$_': $_[0]{$_}" } sort keys %{$_[0]})."}" };


# Constructor
sub new {
	my $class = shift;

	return bless $_[0]||{}, $class;
}

# Set an key to a value
sub set {
    my $self = shift;
    my ($k, $v) = @_;
    $self->{$k} = $v;
    return $self;
}

1;
