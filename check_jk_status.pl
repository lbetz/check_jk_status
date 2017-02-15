#!/usr/bin/env perl

###############################################################################
##
## check_jk_status:
##
## Check the status for mod_jk's loadbalancers via XML download from status
## URL.
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
##
## $Id: $
##
###############################################################################

use strict;
use Getopt::Long;
use warnings;
use XML::Simple;
use LWP::Simple;
use Data::Dumper;

####################################################
## Global vars
####################################################

## Initialize vars
my $server_ip = '';
my $uri = '/jkmanager';
my $balancer  = '';
my $warning = '';
my $critical = '';

## Get user-supplied options
GetOptions('host=s' => \$server_ip, ,'uri=s' => \$uri, 'balancer=s' =>
\$balancer, 'warning=i' => \$warning, 'critical=i' => \$critical);

####################################################
## Main APP
####################################################

if ( ($server_ip eq '') || ($balancer eq '') || ($warning eq '') ||
($critical eq '') )
{
 print "\nError: Parameter missing\n";
 &Usage();
 exit(1);
}

## Fetch the status
my $xml = GetXML($server_ip);

## Parse the XML and return the results
ParseXML($xml);

###################################################
## Subs / Functions
####################################################

## Print Usage if not all parameters are supplied
sub Usage()
{
 print "\nUsage: check_jk_status [PARAMETERS]

Parameters:
 --host=[HOSTNAME]               : Name or IP address of JK management interface
 --uri=[URI]                     : uri, i.e. /jkmanager
 --balancer=[JK BALANCER]        : Name of the JK balancer, default /jkmanager
 --warning=[WARNING THRESHOLD]   : Warning if under runs
 --critical=[CRITICAL THRESHOLD] : Critical if under runs\n\n";
}

## Fetch the XML from management address
sub GetXML
{
   ### Get the XML page
   my $ip = shift;
   my $url = "http://$ip/$uri/?mime=xml";
   my $page = get $url;
   die "Couldn't get $url" unless defined $page;
   ## Return the XML
   return $page;
}

## Parse the XML and return the results
sub ParseXML
{
   ### Get XML to parse
   my $xml = shift;

   ### Hash for node status
   my @good_members = ();
   my @bad_members = ();

   ### Convert XML to hash
   my $status = XMLin($xml, forcearray => ['jk:balancer','jk:member']);

   ### Exit if specified balancer wasn't found
   PrintExit ("Supplied balancer wasn't found!") unless %{$status->{'jk:balancers'}->{'jk:balancer'}->{$balancer}} ;

   ### Get number of members
   my $member_count = $status->{'jk:balancers'}->{'jk:balancer'}->{$balancer}{'member_count'};

   ### Check all members
   foreach my $member ( sort keys %{$status->{'jk:balancers'}->{'jk:balancer'}->{$balancer}->{'jk:member'}}
)
   {
       ### Check status for every node activation
       my $activation = $status->{'jk:balancers'}->{'jk:balancer'}->{$balancer}->{'jk:member'}->{$member}->{'activation'};
       my $state = $status->{'jk:balancers'}->{'jk:balancer'}->{$balancer}->{'jk:member'}->{$member}->{'state'};

       if ( $activation ne 'ACT' )
       {
           push (@bad_members, $member);
       }
       elsif ( $activation eq 'ACT' )
       {
           if ( (($state ne 'OK') && ($state ne 'OK/IDLE')) && ($state ne 'N/A') )
           {
               #print "STATE: $state\n";
               push (@bad_members, $member);
           }
           else
           {
               push (@good_members, $member);
           }
       }
   }

   ### Calaculate possible differnece
   my $good_boys = $member_count - scalar(@bad_members);

   if ( $good_boys le $critical)
   {
       print "CRITICAL: ".scalar(@bad_members), " of $member_count members are down | members=$good_boys;$warning;$critical \n";
       exit 2;
   }
   elsif ( $good_boys le $warning)
   {
       print "WARNING: ".scalar(@bad_members), " of $member_count members are down |  members=$good_boys;$warning;$critical \n";
       exit 1;
   }
   else
   {
       print "OK: All members are fine | members=$good_boys;$warning;$critical \n";
       exit 0;
   }
}

sub PrintExit
{
   my $msg = shift;
   print $msg;
   exit 1;
}
