#!/Users/brian/bin/perls/perl-latest
use v5.26;
use utf8;
use strict;
use warnings;

my $client_id     = '514850006923-c0mnbi10toa5j0rlpi024fg3lfmrnlln.apps.googleusercontent.com';
my $client_secret = 'o1k5pQb7aSwqvVTYRGM5q8yZ';

use OAuth::Cmdline::GoogleDrive;
use OAuth::Cmdline::Mojo;

my $oauth = OAuth::Cmdline::GoogleDrive->new(
    client_id     => $client_id,
    client_secret => $client_secret,
    login_uri     => "https://accounts.google.com/o/oauth2/auth",
    token_uri     => "https://accounts.google.com/o/oauth2/token",
    scope         => "https://www.googleapis.com/auth/drive
    ",
);

my $app = OAuth::Cmdline::Mojo->new(
    oauth => $oauth,
);

$app->start( 'daemon', '-l', $oauth->local_uri );
