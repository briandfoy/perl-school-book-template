use v5.22;
use feature qw(signatures);
no warnings qw(experimental::signatures);

package Local::Linter::Util 0.01 {
	use open qw(:std :utf8);
	use File::Basename qw(basename);
	use Term::ANSIColor qw(colored);
	use FindBin qw($Bin);
    use lib "$Bin/../lib";
    use Exporter qw(import);

	our @EXPORT = qw(get_all_pods warning);

	sub get_all_pods {
		my $path = "$Bin/../pod/*.pod" =~ s/\x{20}/\\ /gr;
		my @pods = glob $path;
		@pods;
		}

	sub warning ( $message, $line='' ) {
		my $file = basename( $ARGV );
		say colored ['red'], "$file $. $message";
		print $line;
		}
	}

__PACKAGE__
