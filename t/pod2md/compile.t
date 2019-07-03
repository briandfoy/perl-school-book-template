use Test::More;

my $program = 'bin/pod2md';

my $result = `$^X -c $program 2>&1`;

like $result, qr/syntax OK/, "$program compiles";

done_testing;
