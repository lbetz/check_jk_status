# check_jk_status
Plugin for Icinga, Nagios and Shinken to check the apache status.

If the apache status page accessable then this plugin checks for open slots, busy workers and idle workers.

Usage: check_jk_status.pl [OPTIONS]

 -?, --usage
   Print usage information
 -h, --help
   Print detailed help screen
 -V, --version
   Print version information
 --extra-opts=[section][@file]
   Read options from an ini file. See https://www.monitoring-plugins.org/doc/extra-opts.html
   for usage and examples.
 -H, --hostname=STRING
   hostname or ip address to check
 -p, --port=INTEGER
   port, default 80 (http) or 443 (https)
 -u, --uri=STRING
   uri, default /jkmanager
 -U, --username=STRING
   username for basic auth
 -P, --password=STRING
   password for basic auth
 -b, --balancer=STRING
   balancer to check
 -s, --ssl
   use https instead of http
 -N, --no_validate
   do not validate the SSL certificate chain
 -w, --warning=STRING
   warning threshold of failed members
 -c, --critical=STRING
   critical threshold of failed members
 -t, --timeout=INTEGER
   Seconds before plugin times out (default: 15)
 -v, --verbose
   Show details for command-line debugging (can repeat up to 3 times)

Threasholds present numbers of disconnnected workers. If you've a two node cluster and wanna get a warning when one node is offline and a critical for both nodes are offline use:

./check_jk_status.pl -H localhost -b balance1 -w 1 -c 2
JK_STATUS OK - 0 of 2 members are down | members=2;1;2
