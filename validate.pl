#!/usr/bin/perl
#----------------------------------------------------------------------------------
#   The following BEGIN block is required to trap error messages from
#   'use' statements.
#----------------------------------------------------------------------------------
use strict;
use warnings;
my %perl_modules;
my $aleph_id        = $ARGV[0];
my $jboss_port      = $ARGV[1];

die 'No correct Aleph ID was specified.'
    unless (defined($aleph_id)
            and $aleph_id =~ /^\S{1,12}$/);
die 'No correct JBoss port was specified.'
    unless (defined($jboss_port)
            and $jboss_port =~ /^\d+$/
            and $jboss_port > 0 and $jboss_port < 65536);

BEGIN {
    #------------------------------------------------
    # Read the file created by install_adapter.pl.
    #------------------------------------------------
    my $textfile        = 'sql_lookup.txt';
    open(FH1,"<$textfile") or die "Unable to open $textfile\n";
    my $xserver_licensed = <FH1>;
    close(FH1);
    chomp $xserver_licensed;

    my @modules = ('HTTP::Request','LWP::UserAgent','Switch','POSIX');
    if (!$xserver_licensed) {
        push @modules, 'DBI';
        push @modules, 'DBD::Oracle';
    }
    %perl_modules = ();
    foreach (@modules) {
        my $module = $_;
        if (!eval "require $module; 1") {
            $perl_modules{$module} = '[Module not found]';
        } else {
            $perl_modules{$module} = ' [OK]';
        }
    }
}   # End BEGIN block

#-----------------------------------------------
#   Display status of Perl modules
#-----------------------------------------------
print "\nStatus of required Perl modules:\n";
foreach my $key (sort keys %perl_modules) {
    print "\n\t$key\n\t$perl_modules{$key}\n";
}
print "\n";

#-----------------------------------------------
# Construct a url for the Aleph x-server that
# will retrieve a bib record in xml format.
#-----------------------------------------------
my $ua = LWP::UserAgent->new;
my $operation = 'find-doc&doc_number=';
my $x_url = "http://localhost/X?op=bor_by_key&bor_id=$aleph_id";
print "Sending $x_url\n";
my $response = $ua->get($x_url);
if (not $response->is_success or grep /<error>/, $response->content) {
    print "X-server retrieval status:\n\t[failed]\n";
} else {
    print "X-server retrieval status:\n\t[OK]\n";
}
#---------------------------------------------------
# Construct a url for the Aleph REST API that
# will retrieve patron information in xml format.
#---------------------------------------------------
my $rest_url = "http://localhost:PORT/rest-dlf/patron/$aleph_id/patronInformation/address";
$rest_url =~ s/PORT/$jboss_port/g;
print "\nSending $rest_url\n";
$response = $ua->get($rest_url);
if (not $response->is_success or !grep /<reply-code>0000<\/reply-code>/, $response->content) {
    print "REST API retrieval status:\n\t[failed]\n";
} else {
    print "REST API retrieval status:\n\t[OK]\n";
}

#---------------------------------------------------
# Test the retrieval of Aleph version information.
#---------------------------------------------------
my @aleph_info = `./get_aleph_info.csh`;
if (grep /aleph/i, @aleph_info) {
    print "\nAleph version retrieval status:\n\t[OK]\n";
} else {
    print "\nAleph version retrieval status:\n\t[failed]\n";
}

#------------------------------------------------
# Generate a URL for testing the installation.
#------------------------------------------------
die "\n".'$ENV{WWW_HOST} not defined.'
    unless (defined($ENV{WWW_HOST})
            and $ENV{WWW_HOST} !~ /^\s*$/);
my $test_url = "https://$ENV{WWW_HOST}/rest-dlf/patron/$aleph_id/patronInformation/address";
print "\nPut this URL in a browser to test the adapter after all the installation steps are completed.\n\t$test_url\n\n";
exit;

# vim:textwidth=80:expandtab:tabstop=4:shiftwidth=4:fileencodings=utf8:spelllang=en
