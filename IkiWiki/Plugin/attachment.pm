#!/usr/bin/perl
package IkiWiki::Plugin::attachment;

use warnings;
use strict;
use IkiWiki 2.00;
use CGI;
$CGI::DISABLE_UPLOADS=0;
	
# TODO move to admin prefs
$config{valid_attachments}="(*.mp3 and maxsize(15mb)) or (* and maxsize(.50kb))";

sub import { #{{{
	hook(type => "formbuilder_setup", id => "attachment", call => \&formbuilder_setup);
	hook(type => "formbuilder", id => "attachment", call => \&formbuilder);
} # }}}

sub formbuilder_setup { #{{{
	my %params=@_;
	my $form=$params{form};

	return if $form->field("do") ne "edit";

	$form->field(name => 'attachment', type => 'file');
} #}}}

sub formbuilder (@) { #{{{
	my %params=@_;
	my $form=$params{form};

	return if $form->field("do") ne "edit";

	if ($form->submitted eq "Upload") {
		my $q=$params{cgi};
		my $filename=IkiWiki::basename($q->param('attachment'));
		if (! defined $filename || ! length $filename) {
			# no file, so do nothing
			return;
		}
		
		# This is an (apparently undocumented) way to get the name
		# of the temp file that CGI writes the upload to.
		my $tempfile=$q->tmpFileName($filename);
		
		# To untaint the filename, escape any hazardous characters,
		# and make sure it isn't pruned.
		$filename=IkiWiki::possibly_foolish_untaint(IkiWiki::titlepage($filename));
		if (IkiWiki::file_pruned($filename, $config{srcdir})) {
			error(gettext("bad attachment filename"));
		}

		# Check that the attachment matches the configured
		# pagespec.
		my $result=pagespec_match($filename, $config{valid_attachments},
			tempfile => $tempfile);
		if (! $result) {
			error(gettext("attachment rejected")." ($result)");
		}
		
		my $fh=$q->upload('attachment');
		if (! defined $fh || ! ref $fh) {
			error("failed to get filehandle");
		}
		binmode($fh);
		while (<$fh>) {
			print STDERR $_."\n";
		}
	}
} # }}}

package IkiWiki::PageSpec;

sub parsesize { #{{{
	my $size=shift;
	no warnings;
	my $base=$size+0; # force to number
	use warnings;
	my $exponent=1;
	if ($size=~/kb?$/i) {
		$exponent=10;
	}
	elsif ($size=~/mb?$/i) {
		$exponent=20;
	}
	elsif ($size=~/gb?$/i) {
		$exponent=30;
	}
	elsif ($size=~/tb?$/i) {
		$exponent=40;
	}
	return $base * 2**$exponent;
} #}}}

sub match_maxsize ($$;@) { #{{{
	shift;
	my $maxsize=eval{parsesize(shift)};
	if ($@) {
		return IkiWiki::FailReason->new("unable to parse maxsize (or number too large)");
	}

	my %params=@_;
	if (! exists $params{tempfile}) {
		return IkiWiki::FailReason->new("no tempfile specified");
	}

	if (-s $params{tempfile} > $maxsize) {
		return IkiWiki::FailReason->new("attachment too large");
	}
	else {
		return IkiWiki::SuccessReason->new("attachment size ok");
	}
} #}}}

sub match_minsize ($$;@) { #{{{
	shift;
	my $minsize=eval{parsesize(shift)};
	if ($@) {
		return IkiWiki::FailReason->new("unable to parse minsize (or number too large)");
	}

	my %params=@_;
	if (! exists $params{tempfile}) {
		return IkiWiki::FailReason->new("no tempfile specified");
	}

	if (-s $params{tempfile} < $minsize) {
		return IkiWiki::FailReason->new("attachment too small");
	}
	else {
		return IkiWiki::SuccessReason->new("attachment size ok");
	}
} #}}}

1
