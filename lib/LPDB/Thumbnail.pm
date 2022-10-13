package LPDB::Thumbnail;

=head1 NAME

LPDB::Thumbnail - thumbnail images of local pictures/videos in sqlite

=head1 DESCRIPTION

This automatically caches thumnails for C<lpgallery> into a sqlite
database.  Caching is done on-demand by C<Prima::LPDB::ThumbViewer>.

The thumbnail database file is separate from the primary C<LPDB>
database file so that they don't block each other.  The files are
joined by file_id so if the primary database is ever removed the
thumbnails must be removed also to ensure regenerated file_ids will
match.

=cut

use strict;
use warnings;
use Prima;
use LPDB::Schema;
use LPDB::Schema::Object;

=pod

=head1 USAGE

=head2 Methods

=over

=item new LPDB

Return a new Thumnail connection to the database defined in the given
LPDB object, required.

=cut

sub new {
    my($class, $lpdb) = @_;
    my $self = { schema => $lpdb->schema,
		 tschema => $lpdb->tschema,
		 conf => $lpdb->conf };
    my %codec; # heif is newer and clearer than jpeg, only slightly larger
    map { $codec{$_->{name}} = $_->{codecID} } @{Prima::Image->codecs};
    my $c = $codec{libheif} || $codec{JPEG} || $codec{PNG} or
	die "can't find codec for thumbnails";
    $self->{codecID} = $c;
    bless $self, $class;
    return $self;
}

sub _aspect {		    # modified from _draw_thumb of ThumbViewer
    my($sw, $sh, $dw, $dh) = @_;
    my $src = $sw / $sh;	# aspect ratios
    my $dst = $dw / $dh;
    if ($src > $dst) {		# image wider than cell: pad top/bot
	$dh = $dw / $src;
    } else {		      # image taller than cell: pad left/right
	$dw = $dh * $src;
    }
    return $dw, $dh;
}

=pod

=item get ID [CID]

Return the thumnail image of file ID, grabbing and caching it if
needed.  The optional CID is the contact ID of a Picasa face to crop
and return instead.  For videos, CID is instead 0 for the center or
default frame, 1 for the frame at 5% of the time, 3 for the frame at
95% of the time and finally 2 is a high resolution center frame, used
by the C<Prima::LPDB::ImageViewer> video preview image.

=cut

# return thumbnail of given file ID [contact ID or video frame grab]
sub get {
    my($self, $id, $cid, $try) = @_;
    $try ||= 0;
     $try++ > 5
	 and return undef;
    # warn "getting $id from $self\n";
    $cid ||= 0;
    my $tschema = $self->{tschema};
    if (my $this = $tschema->resultset('Thumb')->find(
	    {file_id => $id,
	     contact_id => $cid},
	    {columns => [qw/image/]})) {
	my $data = $this->image;
	unless ($data) {	# try to fix broken save
	    return $self->put($id, $cid) ? $self->get($id, $cid, $try) : undef;
	}
	open my $fh, '<', \$data
	    or die $!;
	binmode $fh;
	my $x = Prima::Image->load($fh)
	    or die $@;
	return $x;
	
    } else {			# not in DB, try to add it
	return $self->put($id, $cid) ? $self->get($id, $cid, $try) : undef;
    }
    return;
}


=pod

=item put ID [CID]

Grab and cache the thumnail for file_id.  This is automatically called
by C<get> when needed so calling it should not be necessary.

=cut

my $tmpfile;			# tmp .jpg file for video thumbnails
BEGIN {				# this probably fails on Windows!!!
    $tmpfile = "/tmp/.lpdb.$$.png"
}				# see $tmp below
END {
    unlink $tmpfile if -f $tmpfile;
}
my @grab = qw/0.5 0.05 0.5 0.95/; # video frame grab positions
my $SIZE = 320;			 # 1920/6=320
sub put {
    my($self, $id, $cid) = @_;
    $cid ||= 0;
    # warn "putting $id/$cid in $self\n";
    my $schema = $self->{schema};
    my $picture = $schema->resultset('Picture')->find(
    	{file_id => $id,
	contact_id => $cid},
	{columns => [qw/basename dir_id width height rotation duration/]});
    my $path = $picture->pathtofile;
    my $modified = -f $path ? (stat _)[9] : 0;
    my $tschema = $self->{tschema};
    my $row = $tschema->resultset('Thumb')->find_or_create(
	{ file_id => $id,
	  contact_id => $cid });
    $modified and $row->modified || 0 >= $modified and
	return $row->image;	# unchanged
    my $i;
    my $tmp;			# used only for video frame grabs
    my @size = ($SIZE, $SIZE);
    # 1, 0, 3 = video stack (0 = random path center), 2 = high-res for IV
    if (my $dur = $picture->duration) {
	my $seek = $dur * $grab[$cid];
	$cid == 2 and @size = (1920, 1080); # high res for ImageViewer
	my $size = sprintf '%dx%d',
	    _aspect($picture->width, $picture->height, @size);
	# warn "$path: seeking to $seek in $dur seconds for $cid @ $size";
	$tmp = $tmpfile;
	my @cmd = (qw(ffmpeg -y -loglevel warning -noautorotate -ss), $seek,
		   '-i', $path, qw(-frames:v 1 -s), $size, $tmp);
	system(@cmd) == 0 or warn "@cmd failed";
    }
    my $codec;
    if ($i = Prima::Image->load($tmp || $path)) {
	# PS: I've read somewhere that ist::Quadratic produces best
	# visual results for the scaled-down images, while ist::Sinc
	# and ist::Gaussian for the scaled-up. /Dmitry Karasik
	$i->scaling(ist::Quadratic);
	if (my $rot = $picture->rotation) {
	    $i->rotate(-1 * $rot);
	}
	$i->size(_aspect($picture->width, $picture->height, @size));
    } else {		    # generate image containing the error text
	my $e = "$@";
	# warn "hello: ", $e;
	my @s = ($SIZE, $SIZE);
	my $b = 10;
	$i = Prima::Image->new(
	    width  => $s[0],
	    height => $s[1],
	    type   => im::bpp8,
	    );
	$i->begin_paint;
	$i->color(cl::Red);
	$i->bar(0, 0, @s);
	$i->color(cl::White);
	$i->font({size => 15, style => fs::Bold});
	$i->draw_text("$path:\n$e",
		      $b, $b, $s[0] - $b, $s[1] - $b,
		      dt::Center|dt::VCenter|dt::Default);
	$i->end_paint;
    }
    my $data;
    open my $fh, '>', \$data
	or die $!;
    binmode $fh;
    $i->save($fh, codecID => $self->{codecID})
	or die $@;
    $row->image($data);
    $row->modified($modified ? time : 0);
    $row->update;
    return $row->image;
}

1;				# LPDB::Thumbnail.pm

=pod

=back

=head1 SEE ALSO

L<lpgallery>, L<Prima::LPDB::ThumbViewer>, L<LPDB>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2022 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
