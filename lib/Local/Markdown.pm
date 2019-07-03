use v5.22;
use utf8;
use feature qw(signatures);
no warnings qw(experimental::signatures);

package Local::Markdown;
use strict;
use parent 'Pod::PseudoPod';

use warnings;
no warnings;

use Carp;

our $VERSION = '0.101';

sub DEBUG () { 0 }

=head1 NAME

Local::Markdown - Turn Pod into Markdown for Pandoc

=head1 SYNOPSIS

	use Local::Markdown;

=head1 DESCRIPTION

***THIS IS ALPHA SOFTWARE. MAJOR PARTS WILL CHANGE***

I wrote just enough of this module to get my job done, and I skipped every
part of the specification I didn't need while still making it flexible enough
to handle stuff later.

=head2 The style information

I don't handle all of the complexities of styles, defining styles, and
all that other stuff. There are methods to return style names, and you
can override those in a subclass.

=cut

=over 4

=cut

sub add_data {
	my( $self, $stuff ) = @_;

	$self->add_to_pad( $stuff );
	$self->escape_and_emit;
	}


sub html_escape_and_emit ( $self ) {
	my $pad = $self->get_pad;

	$self->{$pad} =~ s/\s+\z//;
	$self->{$pad} =~ s/\&
		(?!
			(?:amp|lt|gt|\x23[a-f0-9]+);
		)/&amp;/xgi;

	$self->{$pad} =~ s/</&lt;/g;
	$self->{$pad} =~ s/>/&gt;/g;

	if( $self->{in_verbatim} ) {
		say '=' x 72, "\n", $self->{$pad} if DEBUG > 1;
		$self->{$pad} =~ s|^ \s* B &lt;&lt; \s* (.+?) \s* &gt;&gt; \s* $ |<span class="userinput">$1</span>|mgx;
		$self->{$pad} =~ s|^ \s* B &lt; (.+?) &gt; \s* $ |<span class="userinput">$1</span>|mgx;
		$self->{$pad} =~ s/⏎(?!\v)/⏎\n/g;
		say '-' x 72, "\n", $self->{$pad}, "\n", '_' x 72 if DEBUG > 1;
		}

	$self->emit;
	}

sub add_to_pad ( $self, $stuff ) {
	my $pad = $self->get_pad;
	$self->{$pad} .= $stuff;
	}

sub clear_pad ( $self ) {
	my $pad = $self->get_pad;
	$self->{$pad} = '';
	}

sub set_title           { $_[0]->{title}   = $_[1] }
sub set_chapter         { $_[0]->{chapter} = $_[1] }
sub set_chapter_num     { $_[0]->{chapter_num} = $_[1] }
sub set_label ($p, $label ) {
	$p->{label} = $label;
	}

sub title               { $_[0]->{title}      }
sub chapter             { $_[0]->{chapter}    }
sub label               { $_[0]->{label}      }

sub section             { $_[0]->{section}    }
sub subsection          { $_[0]->{subsection} }
sub subsubsection       { $_[0]->{subsubsection} }
sub subsubsubsection    { $_[0]->{subsubsubsection} }
sub subsubsubsubsection { $_[0]->{subsubsubsubsection} }

sub document_header { return '' }

sub document_footer { return '' }

=back

=head2 The Pod::Simple mechanics

Everything else is the same stuff from C<Pod::Simple>.

=cut

use Data::Dumper;

sub new ( $class ) {
	my $self = $class->SUPER::new();

	my $targets = [
		qw( simpletable table figure note production exercise answer quote )
		];
	my $codes = [
		qw( D G K O P V Y )
		];
	$self->get_ref_labels;

	$self->{accept_targets}{$_}++ for @$targets;
	$self->accept_codes( $_ ) for @$codes;

	$self;
	}

sub get_ref_labels ( $self ) {
	open my $fh, '<', 'refs.txt' or die "Could not find refs.txt!\n";
	while( <$fh> ) {
		chomp;
		my( $link, $text, $label ) = split /\t/;
		DEBUG > 1 and say "Found Label [$label] with text [$text] and link {$link}";
		$self->{_refs}{$label} = { text => $text, link => $link };
		}
	close $fh;
#	say STDERR Dumper( $self->{_refs} ); use Data::Dumper;
	}

sub get_ref_link_by_label ( $self, $label ) {
	if( $self->label_exists( $label ) ) {
		return $self->{_refs}{$label}{'link'}
		}
	$self->my_warn( "Could not find xref link for [$label]" );
	}

sub get_ref_text_by_label ( $self, $label ) {
	if( $self->label_exists( $label ) ) {
		return $self->{_refs}{$label}{'text'}
		}
	$self->my_warn( "Could not find xref text for [$label]" );
	}

sub label_exists ( $self, $label ) { exists $self->{_refs}{$label} }

sub emit ( $self, $level = 0 ) {
	my $text = $self->get_text_from_current_pad;
	print { $self->{'output_fh'} } $text;
	$self->clear_pad;
	return;
	}

sub get_pad {
	# flow elements first
	   if( $_[0]{in_A}      )      { 'ref_text'    }
	elsif( $_[0]{in_B}      )      { 'command_text'}
	elsif( $_[0]{in_D}      )      { 'to_do_text'  }
	elsif( $_[0]{in_G}      )      { 'glossary_text' }
	elsif( $_[0]{in_I}      )      { 'em_text'       }
	elsif( $_[0]{in_L}      )      { 'link_text'   }
	elsif( $_[0]{in_M}      )      { 'module_text' }
	elsif( $_[0]{in_O}      )      { 'object_text' }
	elsif( $_[0]{in_P}      )      { 'entity_text' }
	elsif( $_[0]{in_U}      )      { 'url_text'    }
	elsif( $_[0]{in_V}      )      { 'var_text'    }
	elsif( $_[0]{in_X}      )      { 'index_text'  }
	# then block elements
	elsif( $_[0]{in_figure} )      { 'figure_text' }
	elsif( $_[0]{in_production} )  { 'remark_text' }
	elsif( $_[0]{in_simpletable} ) { 'simpletable_text' }
	elsif( $_[0]{in_note} )        { 'note_text'   }
	# finally the default
	else                           { 'scratch'     }
	}

sub get_text_from_current_pad ( $self ) {
	my $pad = $self->get_pad;
	my $text = $self->{$pad};
	}

sub start_Document ( $self, @_ ) {
	$self->{in_section} = [];
	$self->add_to_pad( $self->document_header );
	$self->emit;
	}

sub end_Document ( $self, @_ ) {
	$self->add_to_pad( $self->document_footer );
	$self->emit;
	}

sub _header_start ( $self, $level ) {
	$self->{in_header} = 1;
	$self->add_to_pad( '#' x ($level + 1) );
	$self->add_to_pad( ' ' );
	}

sub _header_end ( $self, $level ) {
	$self->add_to_pad( "\n\n" );
	$self->emit;
	$self->{in_header} = 0
	}

sub start_head0     ( $self, @args ) {
	$self->_header_start( 0 );
	}
sub end_head0   ( $self, @args ) {
	$self->_header_end( 0 );
	my $chapter = $self->{'chapter'} // 0;

	if( $chapter ) {
		$self->add_to_pad( qq{<p id="chapter-marker" data="$chapter" class="chapter">Chapter $chapter</p>\n\n} );
		}

	$self->emit;
	}

sub start_head1 ( $self, @args ) { $self->_header_start( 1 ) }
sub end_head1   ( $self, @args ) { $self->_header_end(   1 ) }

sub start_head2 ( $self, @args ) { $self->_header_start( 2 ) }
sub end_head2   ( $self, @args ) { $self->_header_end(   2 ) }

sub start_head3 ( $self, @args ) { $self->_header_start( 3 ) }
sub end_head3   ( $self, @args ) { $self->_header_end(   3 ) }

sub start_head4 ( $self, @args ) { $self->_header_start( 4 ) }
sub end_head4   ( $self, @args ) { $self->_header_end(   4 ) }

sub end_non_code_text ( $self ) {
	$self->make_curly_quotes;
	$self->emit;
	}

sub not_for_Para ( $self ) {
	$self->{in_simpletable}
		or $self->{in_figure}
		or $self->{in_production}
		or $self->{in_quote}
	}

sub start_Para ( $self, @args ) {
	return if $self->not_for_Para;
#	$self->html_escape_and_emit;
	$self->{'in_para'} = 1;
	}

sub end_Para  ( $self, @args ) {
	return if $self->not_for_Para;

	if( $self->{in_item_text} ) {
		$self->{'in_item_text'} = 0;
		}
	else {
		$self->{'in_para'} = 0;
		}

	$self->add_to_pad( "\n\n" );
	$self->end_non_code_text;
	}

sub start_Verbatim ( $self, @args ) {
	$self->add_to_pad( qq(<div class="code"><pre class="code">) );
	$self->emit;
	$self->{'in_verbatim'} = 1;
	}

sub end_Verbatim ( $self, @args ) {
# need to handle B<< >> here
	$self->html_escape_and_emit;

	$self->{'in_verbatim'} = 0;
	$self->add_to_pad( qq(</pre></div>\n\n) );
	$self->emit;
	}

sub not_implemented { croak "Not implemented! " . (caller(1))[3] }

=head2 List handling

=cut

sub in_item_list { scalar @{ $_[0]->{list_levels} } }
sub add_list_level_item ( $self ) {
	${ $self->{list_levels} }[-1]{item_count}++;
	}
sub is_first_list_level_item ( $self ) {
	${ $self->{list_levels} }[-1]{item_count} == 0;
	}

sub start_list_level ( $self ) {
	my $self = shift;

	push @{ $self->{list_levels} }, { item_count => 0 };
	}

sub end_list_level ( $self, @args ) {
	pop @{ $self->{list_levels} };
	}

sub start_item ( $self ) {
	$self->add_list_level_item;

	$self->add_to_pad( '* ' );
	$self->emit;

	$self->start_Para;
	}

sub end_item {
	my $self = shift;
	$self->end_Para;
	$self->{in_item} = 0;
	}

sub start_item_bullet { $_[0]->start_item }
sub start_item_number { $_[0]->start_item }
sub start_item_block  { $_[0]->start_item }
sub start_item_text   { $_[0]->{in_item_text}++; $_[0]->start_item }

sub end_item_bullet   { $_[0]->end_item }
sub end_item_number   { $_[0]->end_item }
sub end_item_block    { $_[0]->end_item }
sub end_item_text     { $_[0]->end_item }

sub start_over ( $self ) {
	$self->start_list_level;
	}

sub end_over ( $self ) {
	$self->end_non_code_text;

	$self->end_list_level;
	$self->emit;
	}

sub start_over_bullet { $_[0]->start_over }
sub start_over_text   { $_[0]->start_over }
sub start_over_block  { $_[0]->start_over }
sub start_over_number { $_[0]->start_over }

sub end_over_bullet { $_[0]->end_over }
sub end_over_text   { $_[0]->end_over }
sub end_over_block  { $_[0]->end_over }
sub end_over_number { $_[0]->end_over }

sub _ponder_over {
  my ($self,$para,$curr_open,$paras) = @_;
  return 1 unless @$paras;
  my $list_type;

  if($paras->[0][0] eq '=item') { # most common case
    $list_type = $self->_get_initial_item_type($paras->[0]);

  } elsif($paras->[0][0] eq '=back') {
    # Ignore empty lists by default
    if ($self->{'parse_empty_lists'}) {
      $list_type = 'empty';
    } else {
      shift @$paras;
      return 1;
    }
  } elsif($paras->[0][0] eq '~end') {
    $self->whine(
      $para->[1]{'start_line'},
      "=over is the last thing in the document?!"
    );
    return 1; # But feh, ignore it.
  } else {
    $list_type = 'block';
  }
  $para->[1]{'~type'} = $list_type;
  push @$curr_open, $para;
   # yes, we reuse the paragraph as a stack item

  my $content = join ' ', splice @$para, 2;
  my $overness;
  if($content =~ m/^\s*$/s) {
    $para->[1]{'indent'} = 4;
  } elsif($content =~ m/^\s*((?:\d*\.)?\d+)\s*$/s) {
    no integer;
    $para->[1]{'indent'} = $1;
    if($1 == 0) {
      $self->whine(
        $para->[1]{'start_line'},
        "Can't have a 0 in =over $content"
      );
      $para->[1]{'indent'} = 4;
    }
  } else {
    $self->whine(
      $para->[1]{'start_line'},
      "=over should be: '=over' or '=over positive_number'"
    );
    $para->[1]{'indent'} = 4;
  }
  DEBUG > 1 and print "=over found of type $list_type\n";

  $self->{'content_seen'} ||= 1;
  $self->_handle_element_start((my $scratch = 'over-' . $list_type), $para->[1]);

  return;
}

sub _get_item_type {       # mutates the item!!
  my($self, $para) = @_;
  return $para->[1]{'~type'} if $para->[1]{'~type'};

  # Otherwise we haven't yet been to this node.  Maybe alter it...

  my $content = join "\n", @{$para}[2 .. $#$para];

  if($content =~ m/^\s*\*\s*$/s or $content =~ m/^\s*$/s) {
    # Like: "=item *", "=item   *   ", "=item"
    splice @$para, 2; # so it ends up just being ['=item', { attrhash } ]
    $para->[1]{'~orig_content'} = $content;
    return $para->[1]{'~type'} = 'bullet';

  } elsif($content =~ m/^\s*\*\s+(.+)/s) {  # tolerance

    # Like: "=item * Foo bar baz";
    $para->[1]{'~orig_content'}      = $content;
    $para->[1]{'~_freaky_para_hack'} = $1;
    DEBUG > 2 and print " Tolerating $$para[2] as =item *\\n\\n$1\n";
    splice @$para, 2; # so it ends up just being ['=item', { attrhash } ]
    return $para->[1]{'~type'} = 'bullet';

  } elsif($content =~ m/^\s*(\d+)\.?\s*$/s) {
    # Like: "=item 1.", "=item    123412"

    $para->[1]{'~orig_content'} = $content;
    $para->[1]{'number'} = $1;  # Yes, stores the number there!

    splice @$para, 2; # so it ends up just being ['=item', { attrhash } ]
    return $para->[1]{'~type'} = 'number';

  } else {
    # It's anything else.
    $para->[1]{'~orig_content'} = $content;
    return $para->[1]{'~type'} = 'text';

  }
}

=head2 Note handling

=cut

sub start_note ( $self, $flags ) {
	$self->{in_note} = 1;
	}

sub end_note ( $self, $flags ) {
	$self->emit;
	$self->{in_note} = 0;
	}


=head2 Figure handling

=cut

sub start_figure 	{
	my( $self, $flags ) = @_;
	$self->{in_figure} = 1;
	$self->{figure_title} = $flags->{title};
	}

sub get_next_figure_id {
	my( $self ) = @_;
	$self->title . '-' . $self->label .
		'-FIGURE-' . ++$self->{'figure_count'};

	}

sub get_filenames {
	my( $self ) = @_;
	my $filenames = $self->get_text_from_current_pad;
	$self->clear_pad;

	$filenames =~ s/\A\s+//;
	$filenames =~ s/\s+\z//;

	my @filenames = split /\s+/, $filenames;
	}

sub end_figure {
	my( $self, $flags ) = @_;

	state $inline_images = { map { $_, 1 } qw(
		figs/incoming/dollarat.gif
		figs/incoming/dollarbang.gif
		figs/incoming/dollarquestion.gif
		figs/incoming/dollarunderscore.gif
		figs/incoming/taint.gif
		figs/incoming/taintgrey.gif
		figs/incoming/xarg.gif
		figs/incoming/xro.gif
		figs/incoming/xt.gif
		figs/incoming/xu.gif
		figs/incoming/xwide.gif
		) };

	my @filenames = $self->get_filenames;

	foreach my $file ( @filenames ) {
		my $method = do {
			if( exists $inline_images->{$file} ) { 'make_inline_media_object' }
			else                                 { 'make_figure' }
			};

		$self->$method( $file );
		}

	$self->{figure_title} = '';
	$self->{in_figure} = 0;
	}

sub get_image_type {
	my( $self, $file ) = @_;
	my( $format ) = map { uc } ($file =~ /(gif|p(?:ng|df))\z/ig);
	$format;
	}

sub get_image_dim {
	use Image::Info qw(image_info dim);
	my( $self, $file ) = @_;
	my $info = image_info( $file );
	my( $width, $height ) = dim( $info );
	}

sub make_inline_media_object {
	my( $self, $file ) = @_;

	my $file_type = $self->get_image_type( $file );
	my( $width, $height )     = $self->get_image_dim( $file );
	my $role      = 'right';
	my $align     = 'left';
	my $role      = 'web';
	}

sub make_informal_figure {
	my( $self, $file ) = @_;

	my $id = $self->get_next_figure_id;
	my $file_type = $self->get_image_type( $file );
	my( $width, $height )     = $self->get_image_dim( $file );
	my $role      = 'web';
	}

sub make_figure {
	my( $self, $file ) = @_;

	my $id = $self->get_next_figure_id;
	my $file_type = $self->get_image_type( $file );
	my( $width, $height ) = $self->get_image_dim( $file );
	$self->add_to_pad( <<"HTML" );

<div>
<div class="image center">
<img src="$file" width="$width" height="$height" />
</div>
</div>

HTML

	$self->emit;
	}

sub start_quote ( $self, $flags = {} ) {
	$self->{in_quote} = 1;
	$self->add_to_pad( qq{\n<p class="quote">} );
	$self->emit;
	}

sub end_quote ( $self, $flags = {} ) {
	$self->add_to_pad( qq{</p>\n\n} );
	$self->emit;
	$self->{in_quote} = 0;
	}

sub start_simpletable ($self, $flags = {}) {
	# say "starting simpletable";
	my $title = $flags->{'title'};
	#say "Figure title is [$title]";
	my $name;
	if( $title =~ s/ \A \s* \[ (.+?) \] \s* //x ) {
		$name = $1;
		}
	else {
		$self->my_warn( "No label for simpletable!" );
		}
	#say "Figure name is [$name]";
	my $id = $self->title . '-' . $self->label .
		'-TABLE-' . $name;
	#say "ID is $id";
	$self->emit;

	$self->{in_simpletable} = 1;

	$self->{simpletable_output} = undef;
	open my $fh, '>:utf8', \ $self->{simpletable_output};

	$self->{'old_output_fh'} = $self->{'output_fh'};
	$self->{'output_fh'} = $fh;
	}

sub simplerow ($self, @entries) {
	$self->add_xml_tag( "\t<row>" );
	foreach my $entry ( @entries ) {
		$self->add_xml_tag( "<entry>" );
		$self->add_to_pad( $entry ); $self->emit;
		$self->add_xml_tag( "</entry>" );
		}
	$self->add_xml_tag( "</row>\n" );
	}

sub end_simpletable ($self, $flags = {}) {
	$self->emit;

	open my $fh, '<:utf8', \ $self->{simpletable_output};
	my $text = do { local $/; <$fh> };
	close $fh;
	delete $self->{simpletable_output};
	close $self->{'output_fh'};
	$self->{'output_fh'} = $self->{'old_output_fh'};

#	say "text is [$text]";
	$self->clear_pad;
	my @rows = split /\h*║\h*/, $text;
#	say "There are " . @rows . " rows in the table";
#	say "Row is [@rows]";
	my $header_row = shift @rows;

	$self->add_xml_tag( "<thead>\n" );
	$self->simplerow( split /\s*┃\s*/, $header_row ); # U+2503 BOX DRAWINGS HEAVY VERTICAL

	$self->add_xml_tag( "</thead>\n<tbody>\n" );
	foreach my $row ( @rows ) {
		state $n = 0; $n++;
		$self->simplerow( split /\s*┃\s*/, $row ); # U+2503 BOX DRAWINGS HEAVY VERTICAL
		#say "row $n: $row";
		}
	$self->add_xml_tag( "</tbody>\n</tgroup></table>\n\n" );
	$self->{in_simpletable} = 0;
	#say "Ending simpletable";
	}

sub start_table {
	my( $self, $flags ) = @_;
	$_[0]{'in_bodyrow'} = 0;
	$_[0]{'in_headrow'} = 0;
	$_[0]->{rows} = 0;

	my $title = $flags->{'title'};
	my $name;
	if( $title =~ s/ \A \s* \[ (.*?) \] \s* //x ) {
		$name = $1;
		}
	else {
		$self->my_warn( "No label for table!" );
		}

	my $id = $self->title . '-' . $self->label .
		'-TABLE-' . $name;
	$self->add_xml_tag(
		qq|<table id="$id">\n| .
		qq|<title>$title</title>\n| .
		qq|<tgroup cols="2">\n|
		);
	}

sub end_table      {
	$_[0]{'in_bodyrow'} = 0;
	$_[0]{'in_headrow'} = 0;
	$_[0]->{rows} = 0;
	}

sub start_headrow  {
	$_[0]->{rows} = 0;
	$_[0]{entry} = 0;
	$_[0]{'in_headrow'} = 1;
	$_[0]{'in_bodyrow'} = 0;
	}

sub start_bodyrows {
	$_[0]->end_row;
	$_[0]->{rows} = 0;
	$_[0]{entry} = 0;
	$_[0]{'in_bodyrow'} = 1;
	$_[0]{'in_headrow'} = 0;
	}

sub start_row {
	$_[0]->{rows}++;
	$_[0]->{entry} = 0;
	}

sub end_row {
	}

sub start_cell {
	$_[0]->start_row if $_[0]{rows} == 0;
	$_[0]->{entry}++;
	$_[0]->add_xml_tag( qq(</entry>\n) ) if $_[0]->{entry} > 1;
	$_[0]->add_xml_tag( qq(\t<entry align="left" valign="top">) )
	}
sub end_cell   { }

sub start_italic  ( $self ) { $self->add_to_pad( '*' )  }
sub end_italic    ( $self ) { $self->add_to_pad( '*' )  }

sub start_bold    ( $self ) { $self->add_to_pad( '**' ) }
sub end_bold      ( $self ) { $self->add_to_pad( '**' ) }

sub start_literal ( $self ) { $self->add_to_pad( '`' )  }
sub end_literal   ( $self ) { $self->add_to_pad( '`' )  }

sub start_A ( $self, @args ) { $self->emit; $self->{in_A} = 1 }
sub end_A   ( $self, @args ) {
	my $label = $self->get_text_from_current_pad;
	$self->clear_pad;

	my( $link, $text ) = do {
		   if( $self->label_exists( $label ) ) {
		   	map { $self->$_($label) } qw(
		   		get_ref_link_by_label
		   		get_ref_text_by_label
		   		);
		   	}
		else {
			$self->my_warn( "Fallthrough: Found odd reference [$label]" );
			();
			}
		};

	DEBUG and say "Reference: old link: $label new_link: $text";

	if( $ENV{STUB_REFS} ) {
		$self->my_warn(  "Skipping link to ref $link because STUB_REFS" );
		$self->add_to_pad( '**!!REF!!**' );
		}
	elsif( not defined $text ) {
		$self->my_warn( "Skipping link to ref [$label] because I don't recognize it" );
		$self->add_to_pad( '**!!REF!!**' );
		}
	else {
		$self->add_to_pad( qq|[$text]($link)| );
		}

	$self->emit;
	$self->{in_A} = 0;
	}

sub end_B   ( $self, @args ) { $self->end_bold }
sub start_B ( $self, @args ) { $self->start_bold }

sub end_C   { $_[0]->start_literal; $_[0]->{in_C} = 0; }
sub start_C { $_[0]->start_literal; $_[0]->{in_C} = 1; }

sub end_D ( $self, @args ) {
	my $text = $self->get_text_from_current_pad;
	$self->clear_pad;
	$self->{in_D} = 0;
	$self->add_to_pad( "/TO DO/ $text" );
	$self->end_bold;
	}
sub start_D ( $self, @args ) {
	$self->start_bold;
	$self->{in_D} = 1;
	}

sub end_F   { $_[0]->start_italic }
sub start_F { $_[0]->end_italic   }


sub link_already_defined ( $self, $link ) {
	exists $self->{links}{$link};
	}

sub make_ref ( $self, $text ) {
	$text = $text;
	$text =~ s/\s+/-/gr;
	$text =~ s/[^a-z]/-/igr;
	}

sub end_I   { $_[0]->start_italic }
sub start_I { $_[0]->end_italic   }

sub _treat_Ls { }
sub end_L ( $self, @args ) {
	my $original = $self->get_text_from_current_pad;
	$self->clear_pad;
	my $emphasis;

	my( $link, $text ) = do {
		if( $original =~ /(\w+)\(\d\)/p ) { #manpage
			( ${^MATCH}, "some link" );
			}
		elsif( $original =~ /\A(perl.*?)\|(#.+)/ ) { # anchor into page
			my $page = $1;
			my $anchor = $2 =~ s/-/ /gr;
			$anchor =~ s/#//;
			$anchor =~ s/%22//g;
			( "http://perldoc.perl.org/$page.html$2", "“$anchor” in $page" );
			$emphasis = 1;
			}
		elsif( $original =~ /\A(perl.*)/ ) { # anchor into page
			( "http://perldoc.perl.org/$1.html", $1 );
			}
		elsif( $original =~ /(.*?)\|(https?:.*?)/i ) { # page with user supplied link text
			( $2, $1 );
			}
		else {
			$self->my_warn( "No URL for [$original]" );
			$original
			}
		};

	$self->start_italic if $emphasis;
	my $link_text = $self->make_link( $text, $link );
	$self->add_to_pad( $link_text );
	$self->end_italic if $emphasis;
	$self->emit;
	$self->{in_L} = 0;
	}
sub start_L ( $self, @args ) {
	$self->emit;
	$self->{in_L} = 1;
	}

sub start_M ( $self, @args ) {
	$self->emit;
	$self->{in_M} = 1;
	$self->clear_pad;
	}
sub end_M  ( $self, @args ) {
	my $module = $self->get_text_from_current_pad;
	$self->{'in_M'} = 0;

	$self->start_literal;
	$self->add_to_pad( $module );
	$self->end_literal;
	}


sub start_T ( $self, @args ) {
	$self->emit;
	$self->{in_T};
	$self->clear_pad;
	}
sub end_T ( $self, @args ) {
	state $books = {
		'Learning Perl 6'                              => 'https://www.learningperl6.com/',
		'Learning Perl'                                => 'https://www.learning-perl.com/',
		'Intermediate Perl'                            => 'https://www.intermediateperl.com/',
		'Mastering Perl'                               => 'https://www.masteringperl.org/',
		'Mastering Regular Expressions'                => 'http://my.safaribooksonline.com/book/programming/regular-expressions/0596528124',
		'The Perl Cookbook'                            => 'http://my.safaribooksonline.com/book/programming/perl/0596003137',
		'Star Wars'                                    => 'http://www.starwars.com/',
		'Advanced Programming in the UNIX Environment' => 'http://my.safaribooksonline.com/book/programming/unix/0201433079',
		"Mastering Algorithms with Perl"               => 'http://my.safaribooksonline.com/book/programming/perl/1565923987',
		"Modern Perl"                                  => 'http://onyxneon.com/books/modern_perl/',
		"Perl 5 Pocket Reference"                      => 'http://my.safaribooksonline.com/book/programming/perl/9781449311186',
		"Programming Perl"                             => 'https://www.programmingperl.org/',
		'Learning Perl Student Workbook'               => "http://my.safaribooksonline.com/book/programming/perl/9781449328047",
		"Programming perl"                             => "https://www.programmingperl.org/",
		"Effective Perl Programming"                   => "https://www.effectiveperlprogramming.com/",
		"Object-Oriented Perl"                         => 'https://amzn.to/2OZkWoG',
		"Programming the Perl DBI"                     => "https://amzn.to/2NlCrPu",
		"Network Programming with Perl"                => "https://amzn.to/2LpleD9",
		"Web Client Programming with Perl"             => "https://amzn.to/2BKyEtY",
		"Perl One-Liners"                              => "https://amzn.to/2NiSD4p",
		"HTTP: The Definitive Guide"                   => "https://amzn.to/2PBWjiS"
		};

	my $title = $self->get_text_from_current_pad;
	$self->clear_pad;

	if( exists $books->{$title} ) {
		$self->start_italic;
		my $link_text = $self->make_link( $title, $books->{$title} );
		$self->add_to_pad( $link_text );
		$self->end_italic;
		}
	else {
		$self->my_warn( "Book [$title] has no link\n" );
		$self->add_to_pad( $title );
		}
	$self->emit;
	$self->clear_pad;
	$self->{in_T} = 0;
	}

sub make_link ( $self, $text, $url ) {
	"[$text]($url)";
	}

sub start_U ( $self, @args ) { $_[0]->emit; $_[0]->{in_U} = 1 }
sub end_U ( $self, @args ) {
	my $text = $_[0]->get_text_from_current_pad;
	$_[0]->clear_pad;

	my( $url, $link_text ) = split /\|/, $text, 2;
	$link_text //= $url;

	if( $url =~ /@/ ) {
		$link_text = $url;
		$url = "mailto:$url";
		}

	my $link_text = $self->make_link( $link_text, $url );
	$self->add_to_pad( $link_text );
	$_[0]->emit;
	$_[0]->{in_U} = 0;
	}



sub start_Z { $_[0]->escape_and_emit; $_[0]->{in_Z} = 1;  }
sub end_Z   { $_[0]->clear_pad; $_[0]->{in_Z} = 0; }

sub my_warn {
	my( $self, @texts ) = @_;
	++$self->{'errors_seen'};
	++$self->{'Errata_seen'};
	local $" = '';

	my $errata = $self->{'all_errata'}{ $self->{line_count} };
	my $message = join "\n", @texts;
	push @$errata, $message;
	$self->_complain_warn( $self->{line_count}, $message ) if $self->{'complain_stderr'};
	push @{$self->{'errata'}{$self->{line_count}}}, $message;
	}

sub handle_text ( $self, $text ) {
#	$self->escape_text( \$text );

	if( $self->{in_figure} ) {
		$self->add_to_pad( ' ' ); # separate filenames
		}
	if( $self->{in_simpletable} ) {
		#say "in simpletable with $text in pad $pad";
		}
	if( $self->{in_header} ) {
		$self->{header_text} = $text;
		}
	if( $self->{in_quote} ) {
		$text =~ s/\R+\z//;
		}

	$self->add_to_pad( $text );

	unless( $self->dont_escape ) {
		$self->make_curly_quotes;
		$self->make_em_dashes;
		$self->make_ellipses;
		}
	}

sub dont_escape {
	my $self = shift;
	$self->{in_verbatim} || $self->{in_C} || $self->{in_X}
	}

sub escape_text ( $self, $text_ref ) {
#	I'm not targeting XML so I don't need these, but not confident
#   enough yet to remove it.
#	$$text_ref =~ s/&(?!(?:lt|gt|amp|#x(?:[a-f0-9]+));)/&amp;/gi;
#	$$text_ref =~ s/</&lt;/g;
#	$$text_ref =~ s/>/&gt;/g;

	return 1;
	}

sub make_curly_quotes {
	my( $self ) = @_;

	my $pad  = $self->get_pad;
	my $text = $self->{$pad};

	require Tie::Cycle;

	tie my $cycle, 'Tie::Cycle', [ qw( “ ” ) ];

	1 while $text =~ s/"/$cycle/;

	# single quotes are weird because they mostly don't
	# come in pairs
	$text =~ s/(^|\s)'/$1‘/g;  # left
	$text =~ s/'/’/g;          # right

	$self->{$pad} = $text;

	return 1;
	}

sub make_em_dashes {
	my( $self ) = @_;
	return if $self->{in_verbose};
	my $pad  = $self->get_pad;
	$_[0]->{$pad} =~ s/--/—/g;  # 0x2016
	return 1;
	}

sub make_ellipses {
	my( $self ) = @_;
	my $pad  = $self->get_pad;
	$self->{$pad} =~ s/\Q.../…/g; # 0x2026
	return 1;
	}

BEGIN {
require Pod::Simple::BlackBox;

package Pod::Simple::BlackBox;

sub InFancyDash {
	return <<"CODE_NUMBERS";
2010 2015
2212
FE58
CODE_NUMBERS
	}

sub _ponder_Verbatim {
	my ($self,$para) = @_;
	DEBUG and print STDERR " giving verbatim treatment...\n";

	$para->[1]{'xml:space'} = 'preserve';

	# strip trailing whitespace
	s/\h+$// foreach ( @$para[ 2 .. $#$para ] );

	# remove leading blank lines
	while( $para->[2] =~ m/ \A \h* $ /x ) {
		splice @$para, 2, 1, ();
		}

	# find the leading whitespace on the first line
	my( $leader ) = $para->[2] =~ m/ \A (\h+) /x;

	foreach my $line ( @$para[ 2 .. $#$para ] ) {
		$line =~ s/ \A \Q$leader\E //x;

		$self->my_warn(
				"tab in code listing!\n\t$line",
			) if $line =~ /\t/;

		if( $line =~ /\p{InFancyDash}/ ) {
			# only if it's not in a comment
			my $post_comment = $line =~ s/.*?#//r;

			$self->my_warn(
					"fancy dash in code listing!\n\t$line",
				) unless $post_comment =~ /\p{InFancyDash}/; # −
			}
  		}

  # Now the VerbatimFormatted hoodoo...
  if( $self->{'accept_codes'} and
      $self->{'accept_codes'}{'VerbatimFormatted'}
  ) {
    while(@$para > 3 and $para->[-1] !~ m/\S/) { pop @$para }
     # Kill any number of terminal newlines
    $self->_verbatim_format($para);
  } elsif ($self->{'codes_in_verbatim'}) {
    push @$para,
    @{$self->_make_treelet(
      join("\n", splice(@$para, 2)),
      $para->[1]{'start_line'}, $para->[1]{'xml:space'}
    )};
    $para->[-1] =~ s/\n+$//s; # Kill any number of terminal newlines
  } else {
    push @$para, join "\n", splice(@$para, 2) if @$para > 3;
    $para->[-1] =~ s/\n+$//s; # Kill any number of terminal newlines
  }
  return;
}

}

BEGIN {
use Pod::PseudoPod;

package Pod::PseudoPod;

sub _ponder_begin {
  my ($self,$para,$curr_open,$paras) = @_;

  unless ($para->[2] =~ /^\s*(?:(?:simple)?table|sidebar|figure|exercise|answer|listing|production|note|quote)/) {
    return $self->SUPER::_ponder_begin($para,$curr_open,$paras);
  }

  my $content = join ' ', splice @$para, 2;
  $content =~ s/^\s+//s;
  $content =~ s/\s+$//s;

  my ($target, $title) = $content =~ m/^(\S+)\s*(.*)$/;
  $title =~ s/^(picture|html)\s*// if ($target =~ m'table');
  $para->[1]{'title'} = $title if ($title);
  $para->[1]{'target'} = $target;  # without any ':'

  return 1 unless $self->{'accept_targets'}{$target};

  $para->[0] = '=for';  # Just what we happen to call these, internally
  $para->[1]{'~really'} ||= '=begin';
#  $para->[1]{'~ignore'}  = 0;
  $para->[1]{'~resolve'} = 1;

  push @$curr_open, $para;
  $self->{'content_seen'} ||= 1;
  $self->_handle_element_start($target, $para->[1]);

  return 1;
}

sub _ponder_end {
  my ($self,$para,$curr_open,$paras) = @_;
  my $content = join ' ', splice @$para, 2;
  $content =~ s/^\s+//s;
  $content =~ s/\s+$//s;
  DEBUG and print "Ogling '=end $content' directive\n";

  unless(length($content)) {
    if (@$curr_open and $curr_open->[-1][1]{'~really'} eq '=for') {
      # =for allows an empty =end directive
      $content = $curr_open->[-1][1]{'target'};
    } else {
      # Everything else should complain about an empty =end directive
      my $complaint = "'=end' without a target?";
      if ( @$curr_open and $curr_open->[-1][0] eq '=for' ) {
        $complaint .= " (Should be \"=end " . $curr_open->[-1][1]{'target'} . '")';
      }
      $self->whine( $para->[1]{'start_line'}, $complaint);
      DEBUG and print "Ignoring targetless =end\n";
      return 1;
    }
  }

  unless($content =~ m/^\S+$/) {  # i.e., unless it's one word
    $self->whine(
      $para->[1]{'start_line'},
      "'=end $content' is invalid.  (Stack: "
      . $self->_dump_curr_open() . ')'
    );
    DEBUG and print "Ignoring mistargetted =end $content\n";
    return 1;
  }

  $self->_ponder_row_end($para,$curr_open,$paras) if $content eq 'table';

  unless(@$curr_open and $curr_open->[-1][0] eq '=for') {
    $self->whine(
      $para->[1]{'start_line'},
      "=end $content without matching =begin.  (Stack: "
      . $self->_dump_curr_open() . ')'
    );
    DEBUG and print "Ignoring mistargetted =end $content\n";
    return 1;
  }

  unless($content eq $curr_open->[-1][1]{'target'}) {
    if ($content eq 'for' and $curr_open->[-1][1]{'~really'} eq '=for') {
      # =for allows a "=end for" directive
      $content = $curr_open->[-1][1]{'target'};
    } else {
      $self->whine(
        $para->[1]{'start_line'},
        "=end $content doesn't match =begin "
        . $curr_open->[-1][1]{'target'}
        . ".  (Stack: "
        . $self->_dump_curr_open() . ')'
      );
      DEBUG and print "Ignoring mistargetted =end $content at line $para->[1]{'start_line'}\n";
      return 1;
    }
  }

  # Else it's okay to close...
  if(grep $_->[1]{'~ignore'}, @$curr_open) {
    DEBUG > 1 and print "Not firing any event for this =end $content because in an ignored region\n";
    # And that may be because of this to-be-closed =for region, or some
    #  other one, but it doesn't matter.
  } else {
    $curr_open->[-1][1]{'start_line'} = $para->[1]{'start_line'};
      # what's that for?

    $self->{'content_seen'} ||= 1;
    if ($content eq 'note'
    	or $content eq 'production'
    	or $content eq 'simpletable'
    	or $content eq 'table'
    	or $content eq 'sidebar'
    	or $content eq 'figure'
    	or $content eq 'listing'
    	or $content eq 'exercise'
    	or $content eq 'answer'
    	or $content eq 'quote'
    	) {
      $self->_handle_element_end( $content );
    } else {
      $self->_handle_element_end( 'for', { 'target' => $content } );
    }
  }
  DEBUG > 1 and print "Popping $curr_open->[-1][0] $curr_open->[-1][1]{'target'} because of =end $content\n";
  pop @$curr_open;

  return 1;
}
}



BEGIN {

# override _treat_Es so I can localize e2char
sub _treat_Es {
	my $self = shift;

	require Pod::Escapes;
	local *Pod::Escapes::e2char = *e2char_tagged_text;

	$self->SUPER::_treat_Es( @_ );
	}

sub e2char_tagged_text {
	package Pod::Escapes;

	my $in = shift;
	return unless defined $in and length $in;

	   if( $in =~ m/^(0[0-7]*)$/ )         { $in = oct $in; }
	elsif( $in =~ m/^0?x([0-9a-fA-F]+)$/ ) { $in = hex $1;  }

	if( $NOT_ASCII ) {
		unless( $in =~ m/^\d+$/ ) {
			$in = $Name2character{$in};
			return unless defined $in;
			$in = ord $in;
	    	}

		return $Code2USASCII{$in}
			|| $Latin1Code_to_fallback{$in}
			|| $FAR_CHAR;
		}

 	if( defined $Name2character_number{$in} and $Name2character_number{$in} < 127 ) {
 		return "&$in;";
 		}
	elsif( defined $Name2character_number{$in} ) {
		# this needs to be fixed width because I want to look for
		# it in a negative lookbehind
		return sprintf '&#x%04x;', $Name2character_number{$in};
		}
	else {
		return '???';
		}

	}
}

=head1 TO DO


=head1 SEE ALSO

L<Pod::PseudoPod>, L<Pod::Simple>

=head1 SOURCE AVAILABILITY

This source is in Github:

	http://github.com/briandfoy/Pod-DocBook

If, for some reason, I disappear from the world, one of the other
members of the project can shepherd this module appropriately.

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2010, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

sub _ponder_paragraph_buffer {

  # Para-token types as found in the buffer.
  #   ~Verbatim, ~Para, ~end, =head1..4, =for, =begin, =end,
  #   =over, =back, =item
  #   and the null =pod (to be complained about if over one line)
  #
  # "~data" paragraphs are something we generate at this level, depending on
  # a currently open =over region

  # Events fired:  Begin and end for:
  #                   directivename (like head1 .. head4), item, extend,
  #                   for (from =begin...=end, =for),
  #                   over-bullet, over-number, over-text, over-block,
  #                   item-bullet, item-number, item-text,
  #                   Document,
  #                   Data, Para, Verbatim
  #                   B, C, longdirname (TODO -- wha?), etc. for all directives
  #

  my $self = $_[0];
  my $paras;
  return unless @{$paras = $self->{'paras'}};
  my $curr_open = ($self->{'curr_open'} ||= []);

  DEBUG > 10 and print "# Paragraph buffer: <<", pretty($paras), ">>\n";

  # We have something in our buffer.  So apparently the document has started.
  unless($self->{'doc_has_started'}) {
    $self->{'doc_has_started'} = 1;

    my $starting_contentless;
    $starting_contentless =
     (
       !@$curr_open
       and @$paras and ! grep $_->[0] ne '~end', @$paras
        # i.e., if the paras is all ~ends
     )
    ;
    DEBUG and print "# Starting ",
      $starting_contentless ? 'contentless' : 'contentful',
      " document\n"
    ;

    $self->_handle_element_start('Document',
      {
        'start_line' => $paras->[0][1]{'start_line'},
        $starting_contentless ? ( 'contentless' => 1 ) : (),
      },
    );
  }

  my($para, $para_type);
  while(@$paras) {
    last if @$paras == 1 and
      ( $paras->[0][0] eq '=over' or $paras->[0][0] eq '~Verbatim'
        or $paras->[0][0] eq '=item' )
    ;
    # Those're the three kinds of paragraphs that require lookahead.
    #   Actually, an "=item Foo" inside an <over type=text> region
    #   and any =item inside an <over type=block> region (rare)
    #   don't require any lookahead, but all others (bullets
    #   and numbers) do.

# TODO: winge about many kinds of directives in non-resolving =for regions?
# TODO: many?  like what?  =head1 etc?

    $para = shift @$paras;
    $para_type = $para->[0];

    DEBUG > 1 and print "Pondering a $para_type paragraph, given the stack: (",
      $self->_dump_curr_open(), ")\n";

    if($para_type eq '=for') {
      next if $self->_ponder_for($para,$curr_open,$paras);
    } elsif($para_type eq '=begin') {
      next if $self->_ponder_begin($para,$curr_open,$paras);
    } elsif($para_type eq '=end') {
      next if $self->_ponder_end($para,$curr_open,$paras);
    } elsif($para_type eq '~end') { # The virtual end-document signal
      next if $self->_ponder_doc_end($para,$curr_open,$paras);
    }


    # ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
    #~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
    if(grep $_->[1]{'~ignore'}, @$curr_open) {
      DEBUG > 1 and
       print "Skipping $para_type paragraph because in ignore mode.\n";
      next;
    }
    #~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
    # ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

    if($para_type eq '=pod') {
      $self->_ponder_pod($para,$curr_open,$paras);
    } elsif($para_type eq '=over') {
      next if $self->_ponder_over($para,$curr_open,$paras);
    } elsif($para_type eq '=back') {
      next if $self->_ponder_back($para,$curr_open,$paras);
    } elsif($para_type eq '=row') {
      next if $self->_ponder_row_start($para,$curr_open,$paras);

    } elsif( $para_type eq '=headrow'){
    	$self->start_headrow;
    } elsif( $para_type eq '=bodyrows') {
    	$self->start_bodyrows;
    	}

    else {
      # All non-magical codes!!!

      # Here we start using $para_type for our own twisted purposes, to
      #  mean how it should get treated, not as what the element name
      #  should be.

      DEBUG > 1 and print "Pondering non-magical $para_type\n";

      # In tables, the start of a headrow or bodyrow also terminates an
      # existing open row.
      if($para_type eq '=headrow' || $para_type eq '=bodyrows') {
        $self->_ponder_row_end($para,$curr_open,$paras);
      }

      # Enforce some =headN discipline
      if($para_type =~ m/^=head\d$/s
         and ! $self->{'accept_heads_anywhere'}
         and @$curr_open
         and $curr_open->[-1][0] eq '=over'
      ) {
        DEBUG > 2 and print "'=$para_type' inside an '=over'!\n";
        $self->whine(
          $para->[1]{'start_line'},
          "You forgot a '=back' before '$para_type'"
        );
        unshift @$paras, ['=back', {}, ''], $para;   # close the =over
        next;
      }


      if($para_type eq '=item') {
        next if $self->_ponder_item($para,$curr_open,$paras);
        $para_type = 'Plain';
        # Now fall thru and process it.

      } elsif($para_type eq '=extend') {
        # Well, might as well implement it here.
        $self->_ponder_extend($para);
        next;  # and skip
      } elsif($para_type eq '=encoding') {
        # Not actually acted on here, but we catch errors here.
        $self->_handle_encoding_second_level($para);

        next;  # and skip
      } elsif($para_type eq '~Verbatim') {
        $para->[0] = 'Verbatim';
        $para_type = '?Verbatim';
      } elsif($para_type eq '~Para') {
        $para->[0] = 'Para';
        $para_type = '?Plain';
      } elsif($para_type eq 'Data') {
        $para->[0] = 'Data';
        $para_type = '?Data';
      } elsif( $para_type =~ s/^=//s
        and defined( $para_type = $self->{'accept_directives'}{$para_type} )
      ) {
        DEBUG > 1 and print " Pondering known directive ${$para}[0] as $para_type\n";
      } else {
        # An unknown directive!
        DEBUG > 1 and printf "Unhandled directive %s (Handled: %s)\n",
         $para->[0], join(' ', sort keys %{$self->{'accept_directives'}} )
        ;
        $self->whine(
          $para->[1]{'start_line'},
          "Unknown directive: $para->[0]"
        );

        # And maybe treat it as text instead of just letting it go?
        next;
      }

      if($para_type =~ s/^\?//s) {
        if(! @$curr_open) {  # usual case
          DEBUG and print "Treating $para_type paragraph as such because stack is empty.\n";
        } else {
          my @fors = grep $_->[0] eq '=for', @$curr_open;
          DEBUG > 1 and print "Containing fors: ",
            join(',', map $_->[1]{'target'}, @fors), "\n";

          if(! @fors) {
            DEBUG and print "Treating $para_type paragraph as such because stack has no =for's\n";

          #} elsif(grep $_->[1]{'~resolve'}, @fors) {
          #} elsif(not grep !$_->[1]{'~resolve'}, @fors) {
          } elsif( $fors[-1][1]{'~resolve'} ) {
            # Look to the immediately containing for

            if($para_type eq 'Data') {
              DEBUG and print "Treating Data paragraph as Plain/Verbatim because the containing =for ($fors[-1][1]{'target'}) is a resolver\n";
              $para->[0] = 'Para';
              $para_type = 'Plain';
            } else {
              DEBUG and print "Treating $para_type paragraph as such because the containing =for ($fors[-1][1]{'target'}) is a resolver\n";
            }
          } else {
            DEBUG and print "Treating $para_type paragraph as Data because the containing =for ($fors[-1][1]{'target'}) is a non-resolver\n";
            $para->[0] = $para_type = 'Data';
          }
        }
      }

      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      if($para_type eq 'Plain') {
        $self->_ponder_Plain($para);
      } elsif($para_type eq 'Verbatim') {
        $self->_ponder_Verbatim($para);
      } elsif($para_type eq 'Data') {
        $self->_ponder_Data($para);
      } else {
        die "\$para type is $para_type -- how did that happen?";
        # Shouldn't happen.
      }

      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      $para->[0] =~ s/^[~=]//s;

      DEBUG and print "\n", Pod::Simple::BlackBox::pretty($para), "\n";

      # traverse the treelet (which might well be just one string scalar)
      $self->{'content_seen'} ||= 1;
      $self->_traverse_treelet_bit(@$para);
    }
  }

  return;
}

1;
