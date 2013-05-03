#!/usr/bin/perl -l

use strict;
use warnings;
use diagnostics;
diagnostics::enable;
use IO::Socket;

use DPServeur;
use constant DEBUG => 1;

my $port = 2628;

my $server = IO::Socket::INET -> new (Proto => "tcp",
	LocalPort => $port,
	Listen => SOMAXCONN,
	Reuse => 1);

die "Ne peux pas creer de socket sur le port $port: $!" unless $server;

print "Le serveur est en marche";

# pour ne pas avoir de processus zombie
$SIG{"CHLD"}="IGNORE";

while (my $client = $server -> accept() ) {
	print "Le serveur accepte une connexion" if DEBUG;
	my $pid = fork();
	if (!defined $pid) {
		print "Il y a une erreur dans le fork" if DEBUG;
	}
	elsif ($pid) {
			#	print "Je suis le pere" if DEBUG;
		}
		else {
			print "Je suis le fils" if DEBUG;
			#$client -> autoflush(1);
			DPServeur::welcome($client);
			while (1) {
				my $requete = "";
				$requete .= <$client>;
				chomp $requete;
				print "Operation recue: $requete" if DEBUG;
				DPServeur::gestion_requetes($client,$requete);
			}
		}
	}



__END__

=head1 NAME

Serveur - a server implementation of the DICT protocol

=head1 SYNOPSIS

Usage for the serveur script:

  serveur.pl [port]

Examples:

  serveur.pl

  serveur.pl 12345


=head1 DESCRIPTION

A server implementation of the DICT protocol.

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

