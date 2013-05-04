#!/usr/bin/perl -l

use strict;
use warnings;
use diagnostics;
diagnostics::enable;
use IO::Socket;

use DPClient;
use constant DEBUG => 0;

my $host = shift || "localhost";
my $port = shift || "2628";

my $mysock = IO::Socket::INET -> new (Proto => "tcp",
	PeerAddr => "$host:$port")
or die "Ne peut pas me connecter a $host:$port: $!";

my $command = undef;
my $reponse = undef;

#$mysock -> autoflush(1);

print "Connexion reussie au serveur $host:$port" if DEBUG;
$reponse = <$mysock>;
print $reponse;



while (1) {
	printf "? ";
	$command = <stdin>;
	chomp $command;
	print $mysock $command;

	while (1) {
		$reponse = <$mysock>;
		chomp $reponse;
		if($reponse =~/^221/){
			print "$reponse";
			exit(0);
		}
		if (is_error_response ($reponse)) {
	    #print "Erreur recue: $reponse\n";
	    last;
	  }
	  else {
  		print $reponse;
	  	last if $reponse =~ /^((2\d\d)|(420)|(5\d\d))\s+.*$/i;
	  }
	}
}




__END__

=head1 NAME

Client - a client implementation of the DICT protocol

=head1 SYNOPSIS

Usage for the client script:

  client.pl [hostname [port]]

Examples:

  client.pl

  client.pl 127.0.0.1 12345

  client.pl dict.uni-leipzig.de


=head1 DESCRIPTION

A client implementation of the DICT protocol.

DICT is a dictionary network protocol created by the DICT Development Group.
It is described by RFC 2229, published in 1997.


=head1 AUTHOR

David San E<lt>davidsanfr@gmail.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2013 David San E<lt>davidsanfr@gmail.comE<gt>.

=head2 The "MIT" License

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

=cut

