use v5.28;
use utf8;

use Test::More;

my $program = 'bin/pod2md';
my @pods     = qw(
	t/corpus/over.pod
	);

foreach my $pod ( @pods ) {
	my $md = $pod =~ s/\.pod\z/.md/r;
	subtest $pod => sub {
		my $test = 'test-output.md';

		ok -e $pod, "$pod exists (input)";
		ok -e $md,  "$md exists (expected output)";
		unlink $test;
		ok ! -e $test,  "$test doesn't exist yet (actual output)";

		my $command = "$^X $program -O $test $pod";
		my $result = `$command`;
		ok -e $test,  "$test now exists (actual output)";
		}
	}


done_testing();
