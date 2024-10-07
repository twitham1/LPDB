=head1 NAME

LPDB::Picasa - understand .picasa.ini files for LPDB

=cut

package LPDB::Picasa;

use strict;
use warnings;
use File::Basename;
# use Date::Parse;
# use POSIX qw/strftime/;
use LPDB::Schema;
use LPDB::Filesystem;
use base 'Exporter::Tiny';
our @EXPORT = qw(ini_read ini_updatedb);

# return given .picasa.ini file as a hash
sub ini_read {
    my($file) = @_;
    my $data = {};
    my $fh;
    return $data unless open $fh, $file;
    my $section = '';
    my($name, $dir) = fileparse $file;
    $data->{dir} = $dir;
    while (<$fh>) {
	chomp;
	s/\r*\n*$//;
	s/\\n/\n/g;			    # seen in Picasa description
	s/\&\#(\d{3});/sprintf "%c", $1/eg; # seen in album description
	s/\r\n/\n/g;			    # windows CRLF -> unix \n
	if (/^\[([^\]]+)\]/) {
	    $section = $1;
	} elsif (my($k, $v) = split '=', $_, 2) {
	    $data->{$section}{$k} = $v;
	}
    }
    close $fh or warn $!;
    return $data;
}

# update given ini_read hash into LPDB
sub ini_updatedb {
    my($self, $ini) = @_;
    my $dir = $ini->{dir};
    $dir =~ m@/$@ or return;
    my $schema = $self->schema;
    my $did = LPDB::Filesystem::_savedirs($dir); # hack!!! cached dir id
    for my $k (keys %$ini) {
	my $this = $ini->{$k};
	if ($k eq 'dir') {
	    next;
	} elsif ($k =~ /^Picasa/) {
	    # ('name' => 'test',
	    #  'P2category' => 'Folders on Disk',
	    #  'date' => '43258.394167',
	    #  'description' => 'description (optional)
	    #  can be multi-line
	    #  like this...',
	    #  'location' => 'Place taken (optional)')
	} elsif ($k =~ /^Contacts2/) {
	    for my $id (keys %{$this}) {
		my($name, $email) = split ';', $this->{$id};
		my $obj = $schema->resultset('Contact')->find_or_new(
		    { hexid => $id } );
		if ($obj->in_storage) { # last one wins?
		    my $tmp = $obj->email;
		    $obj->email($email);
		    $tmp eq $email or warn "$dir: $tmp -> $email";
		    $tmp = $obj->contact;
		    $obj->contact($name);
		    $tmp eq $name or warn "$dir: $tmp -> $name";
		} else {
		    $obj->hexid($id);
		    $obj->contact($name);
		    $obj->email($email);
		    $obj->insert;
		}
	    }
	} elsif ($k =~ /^\.album:(\w+)$/) {
	    # ('.album:4b5914837de8a11f7029631a2c9280f9' => (
	    # 	 'location' => 'Place taken (optional)',
	    # 	 'name' => 'test - album of kids',
	    # 	 'description' => 'Description (optional)

	    # 	 can be multi-line
	    # 	 like this...',
	    # 	 'token' => '4b5914837de8a11f7029631a2c9280f9',
	    # 	 'date' => '2018-06-07T09:27:35-05:00'
	    #  ))
	} elsif (my $pic = $schema->resultset('Picture')->find(
		     { dir_id => $did,
		       basename => $k })) { # image
	    for (split ';', $this->{faces} || '') {
		my($rect, $hex) = split ',';
		my $contact = $schema->resultset('Contact')->find(
		    { hexid => $hex }) or next;
		my $cid = $contact->contact_id;
		my $face = $schema->resultset('Face')->find_or_create(
		    { dir_id => 0,
		      file_id => $pic->file_id,
		      contact_id => $cid},
		    );
		my($w, $n, $e, $s) = ini_rect($rect);
		my $rot = $pic->rotation;
		my @pos;
		if ($rot == 0) { # most common: no change
		    @pos = ($w, $n, $e, $s);
		} elsif ($rot == 90) {
		    @pos = (1 - $s, $w, 1 - $n, $e);
		} elsif ($rot == 180) {
		    @pos = (1 - $e, 1 - $s, 1 - $w, 1 - $n);
		} elsif ($rot == 270) {
		    @pos = ($n, 1 - $e, $s, 1 - $w);
		} else {	# assume no change
		    @pos = ($w, $n, $e, $s);
		}
		$face->left(shift @pos);
		$face->top(shift @pos);
		$face->right(shift @pos);
		$face->bottom(shift @pos);
		$face->is_changed
		    ? $face->update
		    : $face->discard_changes;
	    }
	    $pic->stars(($this->{star} and $this->{star} eq 'yes') ? 1 : 0);
	    $pic->is_changed
		? $pic->update
		: $pic->discard_changes;
	} elsif (-f "$dir$k") {	# should not fail to find in previous!!!
	    warn "WHY IS $dir$k not in DB?!!!!!!!!!!!!!";
	    for my $id (keys %{$this}) {
		warn "$k\t{$id}{$this->{$id}}\n";
	    }
	} else {
	    warn "[$k] no such file in $dir, ignored\n";
	}
    }
}

# return NW, SE coordinates encoded in $rect
sub ini_rect {
    my($rect) = @_;
    my @out;
    return () unless $rect =~ s/rect64\((\w+)\)/0000000000000000$1/;
    $rect =~ s/.*(\w{16})$/$1/;
    while ($rect =~ s/(....)//) {
	push @out, hex($1) / 65536;
    }
    return @out;
}

1;				# LPDB::Picasa.pm

__END__

=head1 DESCRIPTION

What is Picasa?  Why Picasa?

Picasa was Windows software for managing pictures locally, living from
2002 - 2016.  Google deprecated it to focus on their single photos
platform Google Photos.  But Picasa continues to run well in Wine on
Linux and offers several features for local photo management:

* 100% offline and local - no internet needed and no cloud used

* local automated face detection

* organize and filter photos in several ways: by time, people, albums,
stars, tags and so on

* edit pictures or add captions, tags, text

The last version of Picasa for Windows / Wine was 3.9.141.259

This module reads and understands the .picasa.ini files written by
Picasa and loads them into L<LPDB> for use with L<lpgallery>.  While
currently read-only, options to write .picasa.ini files may be added
in the future.

=head1 SEE ALSO

L<LPDB>, L<lpgallery>, L<Prima>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2024 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
