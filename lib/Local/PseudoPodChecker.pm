
# A quite dimwitted pod2plaintext that need only know how to format whatever
# text comes out of Pod::BlackBox's _gen_errata
use v5.24;

package Local::PseudoPodChecker;
use strict;
use vars qw( $VERSION );
$VERSION = '0.18';
use Carp ();
use base qw( Local::Markdown );
BEGIN { *DEBUG = defined(&Pod::PseudoPod::DEBUG)
          ? \&Pod::PseudoPod::DEBUG
          : sub() {0}
      }

use Text::Wrap 98.112902 (); # was 2001.0131, but I don't think we need that
$Text::Wrap::wrap = 'overflow';
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub any_errata_seen {  # read-only accessor
  return keys %{$_[0]->{'errata'}};
}

sub new {
  my $self = shift;
  my $new = $self->SUPER::new(@_);
  $new->{'output_fh'} //= *STDOUT{IO};

  $new->accept_targets_as_text( qw(author blockquote comment caution
      editor epigraph example figure important note production
      programlisting screen sidebar table tip warning exercise answer) );
  $new->nix_X_codes(1);
  $new->nbsp_for_S(1);
  $new->{'scratch'} = '';
  $new->{'Indent'} = 0;
  $new->{'Indentstring'} = '   ';
  $new->{'Errata_seen'} = 0;
  return $new;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub handle_text {
	$_[0]->add_to_pad( $_[1] );
	$_[0]{'Errata_seen'} and $_[0]{'scratch'} .= $_[1];
	}

sub start_Para  {  $_[0]{'scratch'} = '' }

sub start_head1 {
  if($_[0]{'Errata_seen'}) {
    $_[0]{'scratch'} = '';
  } else {
    if($_[1]{'errata'}) { # start of errata!
      $_[0]{'Errata_seen'} = 1;
      $_[0]{'scratch'} = $_[0]{'source_filename'} ?
        "$_[0]{'source_filename'} -- " : ''
    }
  }
}
sub start_head2 {  $_[0]{'scratch'} = '' }
sub start_head3 {  $_[0]{'scratch'} = '' }
sub start_head4 {  $_[0]{'scratch'} = '' }

sub start_Verbatim    { $_[0]{'scratch'} = ''   }
sub start_item_bullet { $_[0]{'scratch'} = '* ' }
sub start_item_number { $_[0]{'scratch'} = "$_[1]{'number'}. "  }
sub start_item_text   { $_[0]{'scratch'} = ''   }

sub start_over_bullet  { ++$_[0]{'Indent'} }
sub start_over_number  { ++$_[0]{'Indent'} }
sub start_over_text    { ++$_[0]{'Indent'} }
sub start_over_block   { ++$_[0]{'Indent'} }

sub   end_over_bullet  { --$_[0]{'Indent'} }
sub   end_over_number  { --$_[0]{'Indent'} }
sub   end_over_text    { --$_[0]{'Indent'} }
sub   end_over_block   { --$_[0]{'Indent'} }


# . . . . . Now the actual formatters:

sub end_head1       { $_[0]->emit(-4) }
sub end_head2       { $_[0]->emit(-3) }
sub end_head3       { $_[0]->emit(-2) }
sub end_head4       { $_[0]->emit(-1) }
sub end_Para        { $_[0]->emit( 0) }
sub end_item_bullet { $_[0]->emit( 0) }
sub end_item_number { $_[0]->emit( 0) }
sub end_item_text   { $_[0]->emit(-2) }


# . . . . . . . . . . And then off by its lonesome:

sub end_Verbatim  {
  return unless $_[0]{'Errata_seen'};
  my $self = shift;
  if(Pod::Simple::ASCII) {
    $self->{'scratch'} =~ tr{\xA0}{ };
    $self->{'scratch'} =~ tr{\xAD}{}d;
  }

  my $i = ' ' x ( 2 * $self->{'Indent'} + 4);

  $self->{'scratch'} =~ s/^/$i/mg;

  print { $self->{'output_fh'} }   '',
    $self->{'scratch'},
    "\n\n"
  ;
  $self->{'scratch'} = '';
  return;
}

sub end_Document   {
  my ($self) = @_;
  return if $self->{'Errata_seen'};
  print { $self->{'output_fh'} } "\tNo errors seen!\n";
}

sub _ponder_doc_end { 1 }

sub _gen_errata {}

#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
1;

__END__

=head1 NAME

Pod::PseudoPodChecker -- check the PseudoPod syntax of a document

=head1 SYNOPSIS

  use Pod::PseudoPod::Checker;

  my $checker = Pod::PseudoPod::Checker->new();

  ...

  $checker->parse_file('path/to/file.pod');

=head1 DESCRIPTION

This class is for checking the syntactic validity of Pod.
It works by basically acting like a simple-minded version of
L<Pod::PseudoPod::Text> that formats only the "Pod Errors" section
(if Pod::PseudoPod even generates one for the given document).
It's largely unchanged from L<Pod::Simple::Checker>.

=head1 SEE ALSO

L<Pod::PseudoPod>, L<Pod::PseudoPod::Text>, L<Pod::Checker>

=head1 COPYRIGHT

Copyright (c) 2002-2004 Sean M. Burke and Allison Randal.  All rights
reserved.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=head1 AUTHOR

Sean M. Burke C<sburke@cpan.org> and
Allison Randal <allison@perl.org>

=cut

