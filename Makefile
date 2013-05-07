serveur:
	perl serveur.pl

client:
	perl client.pl 127.0.0.1 2628

# the standard dictd server
client-dictorg:
	perl client.pl dict.org

# Official FreeDict server
client-leipzig:
	perl client.pl dict.uni-leipzig.de

check-client-only:
	perl client.pl dict.org < test

check:
	perl serveur.pl & sleep 2 && perl client.pl < test_input | tee test_output && echo "CHECK : don't forget to shutdown the server"
