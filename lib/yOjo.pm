use feature qw(signatures);
no warnings qw(experimental::signatures);

use ojo;

use Exporter qw(import);
our @EXPORT = (
	# new shortcuts
	qw( s cookie ),
	# from ojo
	qw( a b c d f g h j n o p r t u x )
	);

sub S ( $file ) { f( $file )->slurp }
sub cookie ( $url ) { g( $url )->headers->set_cookie }
