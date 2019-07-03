use v5.28;
package Test2::MojoWeb;
use Test2::API 'context';
use feature qw(signatures);
no warnings qw(experimental::signatures);

sub get_ok   { shift->_build_ok( GET   => @_ ) }
sub head_ok  { shift->_build_ok( HEAD  => @_ ) }
sub patch_ok { shift->_build_ok( PATCH => @_ ) }
sub post_ok  { shift->_build_ok( POST  => @_ ) }
sub put_ok   { shift->_build_ok( PUT   => @_ ) }

sub request_ok { shift->_request_ok($_[0], $_[0]->req->url->to_string) }

sub _build_ok ( $self, $method, $url, @args ) {
	my $ctx = context();
	my $rc =  $self->_request_ok(
		$self->ua->build_tx( $method, $url, @args ), $url
		);
	$ctx->ok( $rc );
	$ctx->release;
	return $rc;
	}

sub _request_ok ($self, $tx, $url) {
	my $ctx = context();

	# Perform request
	$self->tx( $self->ua->start($tx) );
	my $err = $self->tx->error;
	my $ok  = !$err->{message} || $err->{code};

	$ctx->diag( $err->{message} ) if ! $ok && $err;

	$ctx->ok( !$ok && $err );
	$ctx->release;

	return $self->_test('ok', $ok, _desc("@{[uc $tx->req->method]} $url"));
	}

sub _test {
  my ($self, $name, @args) = @_;
  local $Test::Builder::Level = $Test::Builder::Level + 2;
  return $self->success(!!Test::More->can($name)->(@args));
}

1;
