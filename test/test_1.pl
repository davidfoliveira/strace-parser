#!/usr/bin/perl

use LWP::Simple qw(get);

my $child = fork();
if ( $child == 0 ) {
	get "http://www.sapo.pt/";
	sleep 1;
}
else {
	print "Waiting for child $child\n";
	waitpid($child,0);
	print "Done";
}
exit 0;
