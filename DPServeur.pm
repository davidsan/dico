package DPServeur;


use strict;
use warnings;
use diagnostics;
diagnostics::enable;
use Sys::Hostname;
use Digest::MD5 qw /md5_hex/;
use POSIX;
use Time::HiRes;
use Levenshtein;
use Text::Soundex;
use utf8;
use Encode qw /encode/;

use constant DEBUG => 0;

BEGIN {
    use Exporter ();
    use vars qw/$APP $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS/;
    $APP         = "dico";
    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = qw/&welcome &gestion_requetes/;
    %EXPORT_TAGS = ();
    @EXPORT_OK   = qw/&welcome &gestion_requetes/;
}

my $dict_rep = "data";
my @commands = qw/QUIT DEFINE SHOW OPTION STATUS MATCH CLIENT HELP/;

my $start_time = Time::HiRes::gettimeofday();

my @sys = uname();
my $host_uname = "@sys[0,2,4]";

my $option = "";

my %strats = (
    exact => "Match headwords exactly",
    prefix => "Match prefixes",
    #nprefix => "Match prefixes (skip, count)",
    substring => "Match substring occurring anywhere in a headword",
    suffix => "Match suffixes",
    re => "POSIX 1003.2 (modern) regular expressions",
    #regexp => "Old (basic) regular expressions",
    soundex => "Match using SOUNDEX algorithm",
    lev => "Match headwords within Levenshtein distance one",
    word => "Match separate words within headwords",
    first => "Match the first word within headwords",
    last => "Match the last word within headwords"
    );
my $debut;

sub welcome {
    my $client = shift;
    $debut = localtime();
    my $msg_id   = md5_hex($debut);
    my $hostname = hostname();
    my $full_msg_id = $msg_id."@".$hostname;
    $msg_id .= '@' . $hostname;
    print $client "220 $hostname $APP $VERSION on $host_uname <none> <$full_msg_id>";
}

sub quit_command {
    my $client = shift;
    print $client "221 bye";
    $client->shutdown(2);
    exit;
}

my $b64_codes =
"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

sub base64_decode {
    my @encode = split //, shift;
    my $s = 0;
    while (@encode) {
        $s *= 64;
        $s += index $b64_codes, shift(@encode);
    }
    return $s;
}

sub define_command {
    my $client   = shift;
    my $database = shift;
    my $mot      = shift;
    my @definitions = ();
    if ( $database =~ /^\*$/ ) {
        @definitions = find_definitions_all($mot);
    }
    elsif ( $database =~ /^!$/ ) {
        @definitions = find_definitions_first_match($mot);
    }
    else {
        my $db = $dict_rep . "/" . $database;
        if (!( -f $db . '.dict' && -f $db . '.index' )) {
            print $client
            "550 invalid database, use \"SHOW DB\" for a list of databases";
            return;
        }
        @definitions = find_definitions_db($database, $mot);
    }
    if (@definitions < 1){
        print $client "552 no match";
        return;
    }
    print $client
    "151 ", scalar(@definitions), " definition retrieved, definition follows";
    foreach my $def (@definitions){
        print $client $def if defined $def;
    }
    print $client ".";
    print $client "250 ok";
}

sub find_definitions_first_match {
    my $mot = shift;
    my @databases = list_valid_db();
    my @definitions = ();
    for my $database (@databases){
        my @tmp=find_definitions_db($database, $mot);
        push @definitions, @tmp;
        last if @tmp;
    }
    return @definitions;
}

sub find_definitions_all {
    my $mot = shift;
    my @databases = list_valid_db();
    my @definitions = ();
    for my $database (@databases){
        push @definitions, find_definitions_db($database, $mot);
    }
    return @definitions;
}

sub find_definitions_db {
    my $database = shift;
    my $mot = shift;
    my $db = $dict_rep . "/" . $database;
    my @definitions=();
    open my $fh, $db . ".index"
    or die "ne peut pas ouvrir le fichier $db.index:$!";
    print "(DEFINE) mot cherche $mot" if DEBUG;
    while ( my $ligne = <$fh> ) {
        if ( $ligne =~ m|^$mot\t([+\w/]+)\t([+\w/]+)$| ) {
            my $decalage = base64_decode($1);
            my $longueur = base64_decode($2);
            open my $fh2, $db . ".dict"
            or die "ne peut pas ouvrir le fichier $db.dict:$!";

            # position du curseur de lecture
            seek $fh2, $decalage, 0;
            my $definition=undef;
            sysread $fh2, $definition, $longueur
            or warn "ne peut pas lire la definition: $!";

            my $hd="151 \"$mot\" $database \"".describe_db($database)."\"\n";
            close $fh2 or die "ne peut pas fermer le fichier: $!";


            if ($option=~/^mime$/i) {
                $hd = encode("MIME-Header", $hd);
                $hd = "Content-Type: text/plain; charset=utf-8\n".$hd;
                $definition = encode("MIME-Header", $definition);
                $definition.="\n";
            }
            my $res = $hd.$definition;
            #print $res;
            $res =~ s|\n|<br/>\n|g if $option=~/^html$/i;
           # print $res;
            push @definitions, $res;
        }
    }
    close $fh or die "ne peut pas fermer le fichier: $!";

    return @definitions;
}

sub describe_db {
    my $database = shift;
    my $db = $dict_rep . "/" . $database;

    open my $fh, $db . ".index"
    or die "ne peut pas ouvrir le fichier $db.index:$!";
    while (my $ligne = <$fh>){
        if ($ligne =~ m|^00databaseshort\t([+\w/]+)\t([+\w/]+)$|){
            my $decalage = base64_decode($1);
            my $longueur = base64_decode($2);
            open my $fh2, $db . ".dict"
            or die "ne peut pas ouvrir le fichier $db.dict:$!";

            # position du curseur de lecture
            seek $fh2, $decalage, 0;
            my $description=undef;
            sysread $fh2, $description, $longueur
            or warn "ne peut pas lire la description: $!";
            close $fh2 or die "ne peut pas fermer le fichier: $!";
            chomp $description;
            return $description;
        }
    }
    die "description du dictionnaire introuvable";
}

sub info_db {
    my $database = shift;
    my $db = $dict_rep . "/" . $database;

    open my $fh, $db . ".index"
    or die "ne peut pas ouvrir le fichier $db.index:$!";
    while (my $ligne = <$fh>){
        if ($ligne =~ m|^00databaseinfo\t([+\w/]+)\t([+\w/]+)$|){
            my $decalage = base64_decode($1);
            my $longueur = base64_decode($2);
            open my $fh2, $db . ".dict"
            or die "ne peut pas ouvrir le fichier $db.dict:$!";

            # position du curseur de lecture
            seek $fh2, $decalage, 0;
            my $description=undef;
            sysread $fh2, $description, $longueur
            or warn "ne peut pas lire la description: $!";
            close $fh2 or die "ne peut pas fermer le fichier: $!";
            chomp $description;
            return $description;
        }
    }
    die "info du dictionnaire introuvable";
}


sub match_command {
    my $client   = shift;
    my $database = shift;
    my $strategy = shift;
    my $query      = shift;
    my @matches = ();
    if (scalar( grep { $strategy =~ /^$_$/i } keys %strats ) != 1){
        print $client "551 invalid strategy, use SHOW STRAT for a list";
        return;
    }
    if ( $database =~ /^\*$/ ) {
        @matches=match_all_db($strategy, $query);
    }
    elsif ( $database =~ /^!$/ ) {
        @matches=match_first_match_db($strategy, $query);
    }
    else {
        my $db = $dict_rep . "/" . $database;
        if (!( -f $db . '.dict' && -f $db . '.index' )) {
            print $client
            "550 invalid database, use \"SHOW DB\" for a list of databases";
            return;
        }
        @matches=match_db($database, $strategy, $query);
    }
    if(@matches < 1){
        print $client "552 no match";
        return;
    }
    print $client "152 ", scalar(@matches), " matches found";
    $"="\n";
    print $client "@matches";
    print $client ".";
    print $client "250 ok";
}

sub match_first_match_db{
    my $strategy = shift;
    my $query = shift;
    my @databases = list_valid_db();
    for my $database (@databases){
        my @tmp=match_db($database, $strategy, $query);
        return @tmp if @tmp;
    }
    return ();
}

sub match_all_db{
    my $strategy = shift;
    my $query = shift;
    my @matches = ();
    my @databases = list_valid_db();
    for my $database (@databases){
        push @matches, match_db($database, $strategy, $query);
    }
    return @matches;
}

sub match_db{
    my $database = shift;
    my $strategy = shift;
    my $query = shift;
    my @matches = ();
    if ($strategy =~ /^exact$/){ @matches = match_db_exact($database, $query); }
    elsif ($strategy =~ /^prefix$/){ @matches = match_db_prefix($database, $query); }
    #elsif ($strategy =~ /^nprefix$/){ @matches = match_db_nprefix($database, $query); }
    elsif ($strategy =~ /^substring$/){ @matches = match_db_substring($database, $query); }
    elsif ($strategy =~ /^suffix$/){ @matches = match_db_suffix($database, $query); }
    elsif ($strategy =~ /^re$/){ @matches = match_db_re($database, $query); }
    #elsif ($strategy =~ /^regexp$/){ @matches = match_db_regexp($database, $query); }
    elsif ($strategy =~ /^soundex$/){ @matches = match_db_soundex($database, $query); }
    elsif ($strategy =~ /^lev$/){ @matches = match_db_lev($database, $query); }
    elsif ($strategy =~ /^word$/){ @matches = match_db_word($database, $query); }
    elsif ($strategy =~ /^first$/){ @matches = match_db_first($database, $query); }
    elsif ($strategy =~ /^last$/){ @matches = match_db_last($database, $query); }
    return @matches;
}

sub match_db_exact{
    my $database = shift;
    my $query = shift;
    my $regex = '^'.$query.'$';
    return match_db_re($database, $regex);
}

sub match_db_re{
    my $database = shift;
    my $regex = shift;
    my $db = $dict_rep . "/" . $database;
    my @matches =();
    open my $fh, $db . ".index"
    or die "ne peut pas ouvrir le fichier $db.index:$!";
    print "(MATCH) regex cherche $regex" if DEBUG;
    while ( my $ligne = <$fh> ) {
        if ( $ligne =~ m|^(.*)\t([+\w/]+)\t([+\w/]+)$| ) {
            my $current_word = $1;
            if($current_word=~/$regex/i){
                push @matches, $database.' "'.$current_word."\"";
            }
        }
    }
    close $fh or die "ne peut pas fermer le fichier: $!";
    return @matches;
}

sub match_db_prefix{
    my $database = shift;
    my $query = shift;
    my $regex = '^'.$query;
    return match_db_re($database, $regex);
}

sub match_db_nprefix{
    # TODO
}

sub match_db_substring{
    my $database = shift;
    my $query = shift;
    my $regex = $query;
    return match_db_re($database, $regex);
}

sub match_db_suffix{
    my $database = shift;
    my $query = shift;
    my $regex = $query.'$';
    return match_db_re($database, $regex);
}

sub match_db_regexp{
    # TODO
}

sub match_db_soundex{
    my $database = shift;
    my $word = shift;
    my $query_word_soundex = soundex($word);
    my $current_soundex ="";
    my $db = $dict_rep . "/" . $database;
    my @matches =();
    open my $fh, $db . ".index"
    or die "ne peut pas ouvrir le fichier $db.index:$!";
    print "(MATCH) soundex cherche $word" if DEBUG;
    while ( my $ligne = <$fh> ) {
        if ( $ligne =~ m|^(.+)\t([+\w/]+)\t([+\w/]+)$| ) {
            my $current_word = $1;
            $current_soundex = soundex($current_word);
            # FIXME: accented characters not handled by soundex
            # example: soundex("à")
            if(defined $current_soundex){
                if($current_soundex =~ /$query_word_soundex/){
                    push @matches, $database.' "'.$current_word."\"";
                }
            }
        }
    }
    close $fh or die "ne peut pas fermer le fichier: $!";
    return @matches;
}

sub match_db_lev{
    # match words which Levenshtein distance is < 2
    my $database = shift;
    my $word = shift;
    my $db = $dict_rep . "/" . $database;
    my @matches =();
    open my $fh, $db . ".index"
    or die "ne peut pas ouvrir le fichier $db.index:$!";
    print "(MATCH) levenshtein cherche $word" if DEBUG;
    while ( my $ligne = <$fh> ) {
        if ( $ligne =~ m|^(.*)\t([+\w/]+)\t([+\w/]+)$| ) {
            my $current_word = $1;
            # compute Levenshtein distance
            my $lev = Levenshtein::levenshtein($word, $current_word);
            if($lev < 2){
                push @matches, $database.' "'.$current_word."\"";
            }
        }
    }
    close $fh or die "ne peut pas fermer le fichier: $!";
    return @matches;
}

sub match_db_word{
    my $database = shift;
    my $query = shift;
    my $regex = '(^|[^\w])'.$query.'([^\w]|$)';
    return match_db_re($database, $regex);
}

sub match_db_first{
    my $database = shift;
    my $query = shift;
    my $regex = '^'.$query.'([^\w]|$)';
    return match_db_re($database, $regex);
}

sub match_db_last{
    my $database = shift;
    my $query = shift;
    my $regex = '(^|[^\w])'.$query.'$';
    return match_db_re($database, $regex);
}

sub list_db_index{
    my @files = glob($dict_rep."/*.index");
    for (@files) {
        s|$dict_rep/||;
    }
    return @files;
}

sub list_db_dict{
    my @files = glob($dict_rep."/*.dict");
    for (@files) {
        s|$dict_rep/||;
    }
    return @files;
}

sub list_valid_db{
    my @indexs = list_db_index();
    my @dicts = list_db_dict();
    my %count;
    my @res;
    for (@indexs) {
        s|.index||;
        $count{$_}++;
    }
    for (@dicts) {
        s|.dict||;
        $count{$_}++;
    }
    foreach (keys %count){
        if($count{$_}==2){
            push @res, $_;
        }
    }
    return @res
}

sub show_db {
    my $client = shift;
    my @databases = list_valid_db();
    print $client "110 ", @databases+0, " databases present";
    for (@databases){
        print $client $_, " \"", describe_db($_), '"';
    }
    print $client ".";
    print $client "250 ok";
}

sub show_strat {
    my $client = shift;
    print $client "111 ", scalar(keys %strats), " databases present";
    foreach (keys %strats){
        print $client $_, " \"", $strats{$_}, '"';
    }
    print $client ".";
    print $client "250 ok";
}

sub show_info_db {
    my $client = shift;
    my $database = shift;
    my $db = $dict_rep . "/" . $database;
    if (!( -f $db . '.dict' && -f $db . '.index' )) {
        print $client
        "550 invalid database, use \"SHOW DB\" for a list of databases";
        return;
    }
    print $client "112 information for ", $database;
    print $client "============ ", $database, " ============";
    print $client info_db($database);
    print $client ".";
    print $client "250 ok";
}

sub show_server {
    my $client   = shift;
    print $client "114 server information";
    print $client "$APP $VERSION on $host_uname";
    my $end = Time::HiRes::gettimeofday();
    printf $client ("uptime : %.2fs\n", $end - $start_time);
    print $client ".";
    print $client "250 ok";
}

sub client_command {
    # this does nothing
    my $client   = shift;
    print $client ".";
    print $client "250 ok";
}

sub option_mime {
    my $client   = shift;
    $option = "mime";
    print $client "250 ok - using MIME headers";
}

sub option_html {
    my $client   = shift;
    $option = "html";
    print $client "250 ok - using HTML format";
}

sub option_off {
    my $client   = shift;
    $option = "";
    print $client "250 ok - all options disabled";
}


sub status_command {
    my $client   = shift;
    print $client "210 this information is worthless and hardcoded"
}

sub help_command {
    my $client   = shift;
    print $client "113 help text follows";
    print $client "DEFINE database word         -- look up word in database";
    print $client "MATCH database strategy word -- match word in database using strategy";
    print $client "SHOW DB                      -- list all accessible databases";
    print $client "SHOW DATABASES               -- list all accessible databases";
    print $client "SHOW STRAT                   -- list available matching strategies";
    print $client "SHOW STRATEGIES              -- list available matching strategies";
    print $client "SHOW INFO database           -- provide information about the database";
    print $client "SHOW SERVER                  -- provide site-specific information";
    print $client "OPTION MIME                  -- use MIME headers";
    print $client "OPTION HTML                  -- use HTML format";
    print $client "OPTION OFF                   -- disable the current option";
    print $client "CLIENT info                  -- identify client to server";
    print $client "STATUS                       -- display timing information";
    print $client "HELP                         -- display this help information";
    print $client "QUIT                         -- terminate connection";
    print $client ".";
    print $client "250 ok";
}

sub gestion_requetes {
    my $client  = shift;
    my $requete = shift;

    if    ( $requete =~ /^q|(quit)|(exit)$/i ) {
        &quit_command( $client );
    }
    elsif ( $requete =~ m|^define (.+) ([-\w. àâäçéèêëîïôöùûü]+)$|i ) {
        &define_command( $client, $1, $2 );
    }
    elsif ( $requete =~ m|^match ([-\w.!\*]+) ([\w.]+) (.+)$|i ) {
        &match_command( $client, $1, $2, $3 );
    }
    elsif ( $requete =~ m/^show (db|databases)$/i ) {
        &show_db( $client );
    }
    elsif ( $requete =~ m/^show (strat|strategies)$/i ) {
        &show_strat( $client );
    }
    elsif ( $requete =~ m|^show info ([-\w.]+)$|i ) {
        &show_info_db( $client, $1 );
    }
    elsif ( $requete =~ m|^show server$|i ) {
        &show_server( $client );
    }
    elsif ( $requete =~ m|^option mime$|i ) {
        &option_mime( $client );
    }
    elsif ( $requete =~ m|^option html$|i ) {
        &option_html( $client );
    }
    elsif ( $requete =~ m|^option off$|i ) {
        &option_off( $client );
    }
    elsif ( $requete =~ m/^client (.+)$/i ) {
        &client_command( $client, $1 );
    }
    elsif ( $requete =~ m|^status$|i ) {
        &status_command( $client );
    }
    elsif ( $requete =~ m|^help$|i ) {
        &help_command( $client );
    }
   # elsif ( scalar( grep { $requete =~ /^$_$/i } @commands ) == 1 ) {
    #    print $client "502 command not implemented";
    #}
    else {
        print $client "500 syntax error, command not recognized";
    }
}

1;
