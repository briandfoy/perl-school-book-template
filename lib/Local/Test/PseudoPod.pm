package Local::Test::PseudoPod;
use v5.28;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use FindBin;
use lib "$FindBin::Bin/../lib";

use Local::PseudoPodChecker;
use Local::Markdown;

use Data::Dumper;
use Exporter qw(import);
use IO::Null;
use Test::Builder;

my $Test = Test::Builder->new();
our @EXPORT = qw( pseudopod_ok );

sub pseudopod_ok ( @pods ) {
	foreach my $file ( @pods ) {
		my $errors;
		my $checker = Local::PseudoPodChecker->new;
		$checker->output_fh( IO::Null->new );
		unless( eval { $checker->parse_file( $file ) } ) {
			$errors++;
			$Test->diag( "Parsing error for $file: $@");
			}

		if( $checker->any_errata_seen ) {
			$errors++;
			$Test->diag( "Errata for $file: ", Dumper( $checker->{errata} ) );
			}

		$Test->ok( ! $errors, "$file has valid pod" )
		}
	}

1;
