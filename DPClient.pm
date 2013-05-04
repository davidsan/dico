package DPClient;

use strict;
use warnings;
use diagnostics;
diagnostics::enable;
use feature qw/ switch /;

use constant DEBUG => 0;

BEGIN {
	use Exporter ();
	use vars qw/$VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS/;
	$VERSION = 1.00;
	@ISA = qw(Exporter);
	@EXPORT = qw/&is_error_response/;
	%EXPORT_TAGS = ();
	@EXPORT_OK = qw/&is_error_response/;
}


sub is_error_response {
	my $reponse = shift;
	if ($reponse =~ /^(\d+)\s+(.*)$/ig) {
		given ($1) {
			when ("420") { print $reponse; return 1;}
			when ("500") { print $reponse; return 1;}
			when ("501") { print $reponse; return 1;}
			when ("502") { print $reponse; return 1;}
			when ("503") { print $reponse; return 1;}
			when ("550") { print $reponse; return 1;}
			when ("551") { print $reponse; return 1;}
			when ("552") { print $reponse; return 1;}
			when ("554") { print $reponse; return 1;}
			when ("555") { print $reponse; return 1;}
			default { return 0; }
		}
	}
}



1;
