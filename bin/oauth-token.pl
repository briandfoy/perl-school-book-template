#!/Users/brian/bin/perls/perl-latest
use v5.26;
use utf8;
use strict;
use warnings;

use OAuth::Cmdline::GoogleDrive;
my $oauth = OAuth::Cmdline::GoogleDrive->new( );
say "Token is: ", $oauth->access_token();
