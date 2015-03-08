#!/usr/bin/perl

use strict;
use warnings;

use Fcntl qw( :mode );

my $get_aleph_info_template_file = 'get_aleph_info.template';
my $get_aleph_info_file          = 'get_aleph_info.csh';

my $api_adapter_template_file    = 'api_adapter.template';
my $api_adapter_file             = 'api_adapter.cgi';

my $sql_lookup_template_file     = 'sql_lookup.csh.template';
my $sql_lookup_file              = 'sql_lookup.csh';

my $sql_lookup_cgi_template_file = 'sql_lookup.cgi.template';
my $sql_lookup_cgi_file          = 'sql_lookup.cgi';

#-------------------------------------------
# Extract the version token from the path
#-------------------------------------------
my $current_user_home_dir = $ENV{HOME};
my $ver;
if ($current_user_home_dir =~ /[au]([^\/]+?)\/alephm$/) {
    $ver = "a$1";
} else {
    die "Unable to extract Aleph version from the current user \$HOME path\n";
}

#-----------------------------------------------------
# Prompt the installer for the institution's name.
#-----------------------------------------------------
my $instname = display(\"\nPlease enter the name of your institution (q=quit): ");

#-----------------------------------------------------------
# Prompt the installer for Aleph's REST API port number.
#-----------------------------------------------------------
my $jboss_port = display(\"\nPlease enter the JBOSS port number for Aleph's REST API (q=quit): ");

#-------------------------------------------------------------------
# Prompt the installer for the license status of Aleph's X-server.
#-------------------------------------------------------------------
my $xsl = display(\"\nIs the X-server licensed for use on this server <y/n>? ");
if (grep /y/i, $xsl) {$xsl = 1} else {$xsl = 0}

#----------------------------------------------------------
# Store this indicator for later reading by validate.pl.
#----------------------------------------------------------
open(OUTPUT,">sql_lookup.txt");
print OUTPUT "$xsl\n";
close(OUTPUT);

my $db_user;
my $db_password;
my $z308_prefix;
if (!$xsl) {
    #-------------------------------------------------------------------
    # Prompt the installer for the Oracle user id of the ADM library,
    # usually <xxx>50, and that user's Oracle password.
    #-------------------------------------------------------------------
    $db_user = display(\"\nPlease enter the Oracle user id for the ADM library (usually <xxx>50): ");

    $db_password = display(\"\nPlease enter the Oracle password for user id $db_user: ");

    $z308_prefix = display(\"\nPlease enter the two-number 'type' prefix from the Z308 Oracle table that corresponds with the identifiers that will be submitted for lookup: ");
}

#-------------------------------------------------------------
# Prompt the installer for a patron's Aleph id to be used
# in testing access to the X-server and REST API.
#-------------------------------------------------------------
my $aleph_id;
if ($xsl) {
     $aleph_id = display(\"\nPlease enter a patron's Aleph id that can be used to test access to the X-server and the REST API: ");
} else {
    $aleph_id = display(\"\nPlease enter a patron's Aleph id that can be used to test access to the REST API: ");
}

#-------------------------------------------------------------------
# Prompt the installer for the IP addresses of the remote servers
# that will call the adapter. These IP addresses will be inserted
# into the adapter's whitelist.
#-------------------------------------------------------------------
my $ip_string = display(\"\nPlease enter the IP addresses of the remote servers that will call the adapter. Separate multiple addresses with commas e.g. 10.10.10.10,11.11.11.11 etc.\n");
my @ip_addresses = split /,/, $ip_string;
foreach (@ip_addresses) {
    $_ = join '', "'", $_, "'"
}
$ip_string = join ',', @ip_addresses;

#----------------------------------------------------------------------
# Generate the get_aleph_info.csh script from a template.
# Substitute the version token into the path of the 'source' command.
#----------------------------------------------------------------------
open(TEMPLATE,"<$get_aleph_info_template_file")  or die "Unable to open input file $get_aleph_info_template_file\n";
open(OUTPUT,">$get_aleph_info_file") or die "Unable to open output file $get_aleph_info_file\n";
while (<TEMPLATE>) {
    if (grep /source/, $_) {
            $_ =~ s/VER/$ver/g;
    }
    print OUTPUT;
}
close(TEMPLATE);
close(OUTPUT);
chmod(S_IRWXU|S_IRGRP|S_IXGRP|S_IROTH|S_IXOTH, "${get_aleph_info_file}");

#----------------------------------------------------------
# Generate the api_adapter.cgi script from a template.
# Substitute the IP addresses into the whitelist.
#----------------------------------------------------------
open(TEMPLATE,"<$api_adapter_template_file")  or die "Unable to open input file $api_adapter_template_file\n";
open(OUTPUT,">$api_adapter_file") or die "Unable to open output file $api_adapter_file\n";
while (<TEMPLATE>) {
    if (grep /WHITELIST/, $_) { $_ =~ s/WHITELIST/$ip_string/g }
    if (grep /PORT/, $_) { $_ =~ s/PORT/$jboss_port/og }
    if (grep /INSTNAME/, $_) { $_ =~ s/INSTNAME/$instname/og }
    print OUTPUT;
}
close(TEMPLATE);
close(OUTPUT);
chmod(S_IRWXU|S_IRGRP|S_IXGRP|S_IROTH|S_IXOTH, "${api_adapter_file}");

#---------------------------------------------------------------
# Optionally, generate the SQL lookup scripts from templates.
#---------------------------------------------------------------
if (!$xsl) {
    #----------------------------------------------------------------------------
    # Generate the sql_lookup.csh script from a template.
    # Substitute the version token into the path of the 'source' command.
    #----------------------------------------------------------------------------
    open(TEMPLATE,"<$sql_lookup_template_file")  or die "Unable to open input file $sql_lookup_template_file\n";
    open(OUTPUT,">$sql_lookup_file") or die "Unable to open output file $sql_lookup_file\n";
    while (<TEMPLATE>) {
        if (grep /VER/, $_) { $_ =~ s/VER/$ver/g }
        print OUTPUT;
    }
    close(TEMPLATE);
    close(OUTPUT);
    chmod(S_IRWXU|S_IRGRP|S_IXGRP|S_IROTH|S_IXOTH, "${sql_lookup_file}");

    #---------------------------------------------------------
    # Generate the sql_lookup.cgi script from a template.
    # Substitute Oracle user id and password, Z308 prefix.
    #---------------------------------------------------------
    open(TEMPLATE,"<$sql_lookup_cgi_template_file")  or die "Unable to open input file $sql_lookup_cgi_template_file\n";
    open(OUTPUT,">$sql_lookup_cgi_file") or die "Unable to open output file $sql_lookup_cgi_file\n";
    while (<TEMPLATE>) {
        if (grep /DBUSER/, $_)     { $_ =~ s/DBUSER/$db_user/g }
        if (grep /DBPASSWORD/, $_) { $_ =~ s/DBPASSWORD/$db_password/g }
        if (grep /Z308PRE/, $_)    { $_ =~ s/Z308PRE/$z308_prefix/g }
        print OUTPUT;
    }
    close(TEMPLATE);
    close(OUTPUT);
    chmod(S_IRWXU|S_IRGRP|S_IXGRP|S_IROTH|S_IXOTH, "${sql_lookup_cgi_file}");
}

#----------------------------
# Validate the installation
#----------------------------
print "\n### Validating the installation ###\n";
my @messages = `./validate.pl $aleph_id $jboss_port`;
foreach (@messages) { print }
exit;

#------------------ Subroutines ------------------
sub display {
    my $text_ref = pop;
    my $input = '';
    while (lc $input ne 'y' && lc $input ne 'n' && lc $input ne 's' && $input eq '') {
            print STDOUT "$$text_ref";
            $input = <STDIN>;
            chomp $input;
    }
    if ($input eq 'q') { exit }
    return $input;
}

# vim:textwidth=80:expandtab:tabstop=4:shiftwidth=4:fileencodings=utf8:spelllang=en
