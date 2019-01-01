#!/usr/bin/env perl

use Monitoring::Plugin;
use Monitoring::Plugin::Getopt;
use Monitoring::Plugin::Threshold;
use XML::Simple;
use LWP::UserAgent;
use Data::Dumper;

## Version
our $VERSION = '1.0.0';

## Create plugin objects
our ($plugin, $options);

$plugin = Monitoring::Plugin->new( shortname => '' );

$options = Monitoring::Plugin::Getopt->new(
  usage   => 'Usage: %s [OPTIONS]',
  version => $VERSION,
  url     => 'https://github.com/lbetz/check_jk_status',
  blurb   => 'Check apache mod_jk status',
);

## Define options
$options->arg(
  spec     => 'hostname|H=s',
  help     => 'hostname or ip address to check',
  required => 1,
);

$options->arg(
  spec     => 'port|p=i',
  help     => 'port, default 80 (http) or 443 (https)',
  required => 0,
);

$options->arg(
  spec     => 'uri|u=s',
  help     => 'uri, default /jkmanager',
  required => 0,
  default => '/jkmanager',
);

$options->arg(
  spec     => 'username|U=s',
  help     => 'username for basic auth',
  required => 0,
);

$options->arg(
  spec     => 'password|P=s',
  help     => 'password for basic auth',
  required => 0,
);

$options->arg(
  spec     => 'balancer|b=s',
  help     => 'balancer to check',
  required => 1,
);

$options->arg(
  spec     => 'ssl|s',
  help     => 'use https instead of http',
  required => 0,
);

$options->arg(
  spec     => 'no_validate|N',
  help     => 'do not validate the SSL certificate chain',
  required => 0,
);

$options->arg(
  spec     => 'warning|w=s',
  help     => 'warning threshold of failed members',
  required => 0,
);

$options->arg(
  spec     => 'critical|c=s',
  help     => 'critical threshold of failed members',
  required => 0,
);

$options->arg(
  spec     => 'extendedperfdata|e',
  help     => 'output extended performance data of balancer and balancer members',
  required => 0,
);

## Get options
$options->getopts();

## Timeout
alarm $options->timeout;

## Set thresholds
$threshold = Monitoring::Plugin::Threshold->set_thresholds(
  warning  => $options->warning,
  critical => $options->critical,
);


####################################################
## Main APP
####################################################

## Set protocol
if (defined($options->ssl)) {
   $proto = 'https://';
} else {
   $proto = "http://";
}

## Username without password
$plugin->nagios_exit( UNKNOWN, 'If you specify an username, you have to set a password too!') if ( ($options->username  ne '') && ($options->password eq '') );

## Password without username
$plugin->nagios_exit( UNKNOWN, 'If you specify a password, you have to set an username too!') if ( ($options->username  eq '') && ($options->password ne '') );

## Set account
if ( ($options->username ne '') && ($options->password ne '') ) {
  $account = $options->username.':'.$options->password.'@';
}

## Set dedicated port
if (defined($options->port)) {
   $url = $proto.$account.$options->hostname.':'.$options->port.$options->uri;
} else {
   $url = $proto.$account.$options->hostname.$options->uri;
}

## Fetch the status
my $xml = GetXML($url);

## Parse the XML and return the results
ParseXML($xml);

###################################################
## Subs / Functions
####################################################

## Fetch the XML from management address
sub GetXML
{
   ### Get URL
   my $url = shift;

   ### Create request
   my $ua = LWP::UserAgent->new( protocols_allowed => ['http','https'], timeout => $options->timeout);

   ### Disable cert validation, if '--ssl' is set
   if (defined($options->no_validate)) {
      $ua->ssl_opts ( verify_hostname => 0 );
   }

   ### Request URL
   my $response = $ua->request( HTTP::Request->new(GET => $url.'/?mime=xml') );

   if (!$response->is_success) {
     $plugin->plugin_exit( UNKNOWN, $response->headers->title );
   }

   ### Return XML content
   return $response->content;
}

## Parse the XML and return the results
sub ParseXML
{
   ### Get XML to parse
   my $xml = shift;

   ### Hash for node status
   my @good_members = ();
   my @bad_members = ();

   ### Hash for extended performance data
   my @perfdata = ();

   ### Convert XML to hash
   my $status = XMLin($xml, forcearray => ['jk:balancer','jk:member']);

   ### Exit if specified balancer wasn't found
   $plugin->nagios_exit( UNKNOWN, 'Supplied balancer was not found!') unless %{$status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}};

   ### Get number of members
   my $member_count = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}{'member_count'};

   ### Check all members
   foreach my $member ( sort keys %{$status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}} ) {
      ### Check status for every node activation
      my $activation = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'activation'};
      my $state = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'state'};
      if (defined($options->extendedperfdata)) {
        $perfdata{$member.'_read'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'read'};
        $perfdata{$member.'_read'}{'uom'} = 'B';
        $perfdata{$member.'_transferred'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'transferred'};
        $perfdata{$member.'_transferred'}{'uom'} = 'B';
        $perfdata{$member.'_sessions'}{'value'} =  $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'sessions'};
        $perfdata{$member.'_sessions'}{'uom'} = 'c';
        $perfdata{$member.'_errors'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'errors'};
        $perfdata{$member.'_errors'}{'uom'} = 'c';
        $perfdata{$member.'_client_errors'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'client_errors'};
        $perfdata{$member.'_client_errors'}{'uom'} = 'c';
        $perfdata{$member.'_reply_timeouts'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'reply_timeouts'};
        $perfdata{$member.'_reply_timeouts'}{'uom'} = 'c';
        $perfdata{$member.'_requests'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'elected'};
        $perfdata{$member.'_requests'}{'uom'} = 'c';
        $perfdata{$member.'_lbvalue'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'lbvalue'};
        $perfdata{$member.'_lbvalue'}{'uom'} = q{};
        $perfdata{$member.'_busy'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'busy'};
        $perfdata{$member.'_busy'}{'uom'} = q{};
        $perfdata{$member.'_max_busy'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'max_busy'};
        $perfdata{$member.'_max_busy'}{'uom'} = q{};
        $perfdata{$member.'_connected'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'connected'};
        $perfdata{$member.'_connected'}{'uom'} = q{};
        $perfdata{$member.'_max_connected'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'max_connected'};
        $perfdata{$member.'_max_connected'}{'uom'} = q{};
        $perfdata{$member.'_time_to_recover_min'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'time_to_recover_min'};
        $perfdata{$member.'_time_to_recover_min'}{'uom'} = 's';
        $perfdata{$member.'_time_to_recover_max'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'time_to_recover_max'};
        $perfdata{$member.'_time_to_recover_max'}{'uom'} = 's';

        ### calculate per second values
        my $last_reset_ago = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'last_reset_ago'};
        if (($last_reset_ago ne "0") && ($last_reset_ago > 0)) {
          $perfdata{$member.'_read_per_sec'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'read'} / $last_reset_ago;
          $perfdata{$member.'_read_per_sec'}{'uom'} = q{};
          $perfdata{$member.'_transferred_per_sec'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'transferred'} / $last_reset_ago;
          $perfdata{$member.'_transferred_per_sec'}{'uom'} = q{};
          $perfdata{$member.'_sessions_per_sec'}{'value'} =  $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'sessions'} / $last_reset_ago;
          $perfdata{$member.'_sessions_per_sec'}{'uom'} = q{};
          $perfdata{$member.'_requests_per_sec'}{'value'} = $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'jk:member'}->{$member}->{'elected'} / $last_reset_ago;
          $perfdata{$member.'_requests_per_sec'}{'uom'} = q{};
        }
      }

      # if a node is in diisable status, skip the other checks
      # nodes marked as failover are in disable status
      if ( $activation eq 'DIS' )
      {
         $member_count = $member_count - 1;
      } elsif ( $activation ne 'ACT' )
      {
         push (@bad_members, $member);
      } elsif ( $activation eq 'ACT' ) {
         if ( (($state ne 'OK') && ($state ne 'OK/IDLE')) && ($state ne 'N/A') ) {
            push (@bad_members, $member);
         } else {
            push (@good_members, $member);
         }
      }
   }

   ### Calaculate possible differnece
   my $bad_boys = $member_count - scalar(@good_members);

   ### Build output
   my $output = $bad_boys." of $member_count members are down";

   ### Set perfdata
   $plugin->add_perfdata(
     label => 'members',
     value => scalar(@good_members),
     uom   => q{},
     threshold => $threshold,
   );

   if (defined($options->extendedperfdata)) {
     #
     ### output balancer performance data
     $plugin->add_perfdata(
       label => $options->balancer.'_good',
       value => $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'good'},
       uom   => q{},
       threshold => q{},
     );
     $plugin->add_perfdata(
       label => $options->balancer.'_degraded',
       value => $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'degraded'},
       uom   => q{},
       threshold => q{},
     );
     $plugin->add_perfdata(
       label => $options->balancer.'_bad',
       value => $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'bad'},
       uom   => q{},
       threshold => q{},
     );
     $plugin->add_perfdata(
       label => $options->balancer.'_busy',
       value => $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'busy'},
       uom   => q{},
       threshold => q{},
     );
     $plugin->add_perfdata(
       label => $options->balancer.'_max_busy',
       value => $status->{'jk:balancers'}->{'jk:balancer'}->{$options->balancer}->{'max_busy'},
       uom   => q{},
       threshold => q{},
     );

     ### output balancer members
     foreach my $member ( sort keys %perfdata) {
       $plugin->add_perfdata(
         label => $member,
         value => $perfdata{$member}{'value'},
         uom   => $perfdata{$member}{'uom'},
         threshold => q{},
       );
     }
   }

   ### Exit status
   $plugin->nagios_exit( $threshold->get_status($bad_boys+1), $output );
}

