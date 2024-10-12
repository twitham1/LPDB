=head1 NAME

LPDB::Filesystem - update sqlite from local picture metadata

=cut

package LPDB::Filesystem;

use strict;
use warnings;
use File::Find;
use Date::Parse;
use Time::Local;
use POSIX qw/strftime/;
use Image::ExifTool qw(:Public);
use LPDB::Schema;
use LPDB::VFS;
use LPDB::Picasa;		# grok .picasa.ini files
use base 'Exporter::Tiny';
our @EXPORT = qw(create update cleanup);

my $exiftool;	  # global hacks for File::Find !!!  We'll never
my $schema;	  # find more than once per process, so this is OK.
my $vfs;	  # LPDB::VFS database methods
my @ini;	  # .picasa.ini files to read after pictures
our $conf;
my $done = time;		# time of last commit
my $tty = -t STDERR;

# create the database from lib/LPDB/*.sql
sub create {
    my $self = shift;
    my $db = $self->conf('dbfile');
    my $thumb = $self->conf('thumbfile');
    my %sql = ('database.sql' => $db,
	       'views.sql'    => $db,
	       'thumbs.sql'   => $thumb);
    # warn "$db already exists!" and return if -f $db;
    # warn "$thumb already exists!" and return if -f $thumb;
    for my $base (sort keys %sql) { # find the .sql in @INC
	for my $path (@INC) {
	    my $sql = "$path/LPDB/$base";
	    if (-f $sql) {
		my $db = $sql{$base};
		warn "create: running sqlite3 $db < $sql\n";
		print `sqlite3 $db < $sql`; # hack!!! any smarter way?
		last;
	    }
	}
    }
    return 1;
}

sub status {
    $tty or return;
    my $t = localtime $done;
    print STDERR "\r\e[J$t    @_      ";
}
END {
    print STDERR "\n";
}

# recursively add given directory or . to LPDB
sub update {
    my($self, @dirs) = @_;
    @dirs or @dirs = ('.');
    $schema = $self->schema;
    $conf = $self->conf;
    if ($conf->{ext}) {		# supported filename extensions
	my @ext = join '|', @{$conf->{ext}};
	my $regex = "\\.(@ext)\$";
	warn $regex;
	$conf->{regex} = $regex;
    }
    # warn "self=$self, conf=$conf, reject=$conf->{reject}";
    # warn "reject: ", $self->conf('reject');
    unless ($vfs) {
	$vfs = new LPDB::VFS($self);
    }
    unless ($exiftool) {
	$exiftool = new Image::ExifTool;
	$exiftool->Options(FastScan => 1,
			   QuickTimeUTC => 1);
	# QuickTimeUTC might lose on cameras that don't know the time
	# zone and use local time against the spec.  But smart phone
	# cameras know the time zone so they use correct UTC time.
    }
    status "update @dirs\n";

    $schema->txn_begin;	   # recurse the filesystem, updating pictures
    @ini = ();
    find ({ no_chdir => 1,
	    preprocess => sub { sort @_ },
	    wanted => \&_wanted,
	    #	    postprocess => $conf->{update},
	  }, @dirs);
    $schema->txn_commit;

    $schema->txn_begin;		# process Picasa text metadata files
    status "update .picasa.ini, .names.txt, .birthdays.txt files\n";
    my @names;
    for my $ini (@ini) {
	if ($ini =~ /.(birthdays|names).txt$/) {
	    push @names, $ini;	# not Picasa, but rather
	    next;		# contacts of whole directory
	}
	my $tmp = ini_read($ini);
	# use Data::Dumper;	# remove this!!! and this:
	# print "\n$ini=", Dumper $tmp;
	ini_updatedb($self, $tmp);
    }
    map { &contacts($schema,  $_) } grep /names/,     @names;
    map { &birthdays($schema, $_) } grep /birthdays/, @names;
    $schema->txn_commit;

    $schema->txn_begin;		# add Picasa [People] = contacts
    status "update [People] contacts\n";
    my $pics = $schema->resultset('PathView')->search(
	{contact_id => { '!=' => undef } },
	{ group_by => [ 'file_id', 'contact_id' ] });
    while (my $pic = $pics->next) {
	my $name = $pic->contact or next;
	$vfs->savepathfile("/[People]/$name/", $pic->file_id);
	#	my $time = $pic->time or next;
	# $vfs->savepathfile("/[People]/$name/All Time/", $pic->file_id);
	# $vfs->savepathfile(strftime("/[People]/$name/Years/%Y/",
	# 			    localtime $time), $pic->file_id);
	# $vfs->savepathfile(strftime("/[People]/$name/Months/%Y-%m-%b/",
	# 			    localtime $time), $pic->file_id);
    }
    $schema->txn_commit;

    $schema->txn_begin;		# add Picasa [Stars] = favorites
    status "update [Stars] = favorites\n";
    $pics = $schema->resultset('PathView')->search(
	{ stars => { '!=' => undef } },
	{ group_by => [ 'file_id', ] });
    while (my $pic = $pics->next) {
	if ($pic->stars) {
	    $vfs->savepathfile("/[Stars]/All Years/", $pic->file_id);
	    my $time = $pic->time or next;
	    $vfs->savepathfile(strftime("/[Stars]/%Y/",
					localtime $time), $pic->file_id);
	} else {
	    # TODO!!! remove star = 0 from Paths
	}
    }
    $schema->txn_commit;
}

# birthdays of contacts (optional death) tab-delimited:
# YYYY/MM/DD	name	YYYYMMDD
sub birthdays {			# (any Date::Parse format works)
    my($schema, $file) = @_;
    open my $fh, $file or return;
    while (my $line = <$fh>) {
	chomp $line;
	my($birth, $name, $death) = split /\t+/, $line;
	$birth and $name or next;
	$birth = str2time($birth) or
	    warn "unparseable time in $file: $line";
	$death and ($death = str2time $death or
		    warn "unparseable time in $file: $line");
	my $c = $schema->resultset('Contact')->search(
	    { contact => $name });
	$c->update({ birth => $birth || undef,
		     death => $death || undef });
    }
}

# file_id = 0 means contact is in all pictures of a directory
sub contacts {			# lines from .names.txt
    my($schema, $file) = @_;
    my($dir) = ($file =~ m{(.*/)});
    open my $fh, $file or return;
    while (my $name = <$fh>) {
	chomp $name;
	s/\s+$//;
	my $row = $schema->resultset('Contact')->find_or_create(
	    { contact => $name });
	$schema->resultset('Face')->find_or_create(
	    { contact_id	=> $row->contact_id,
	      dir_id		=> _savedirs($dir),
	      file_id		=> 0});
    }
}

# add a directory and its parents to the Directories table (see also
# similar savepath of VFS.pm)
{
    my %id;			# cache: {path} = id
    sub _savedirs {		# recursive up to root /
	my($this) = @_;
	defined $this and length $this or $this = './';
	$this =~ m@/$@ or return;
	unless ($id{$this}) {
	    status "updating dir $this";
	    my $obj = $schema->resultset('Directory')->find_or_new(
		{ directory => $this });
	    unless ($obj->in_storage) { # pre-existing?
		my($dir, $file) = LPDB::dirfile $this;
		$obj->parent_id(&_savedirs($dir));
		$obj->insert;
	    }
	    $id{$this} = $obj->dir_id;
	}
	return $id{$this};
    }
}

# update time range of a directory
sub _dirtimes {
    my($id, $time) = @_;
    my $row = $schema->resultset('Directory')->find(
	{ dir_id => $id },
	{ columns => [qw/dir_id begin end/]});
    $row->begin($time)
	unless $row->begin and $row->begin < $time;
    $row->end($time)
	unless $row->end and $row->end > $time;
    $row->is_changed
	? $row->update
	: $row->discard_changes;
}

# add a file or directory to the database, adapted from Picasa.pm
sub _wanted {
    my($dir, $file) = LPDB::dirfile $_;
    my $modified = (stat $_)[9];
    $dir =~ s@\./@@;
    #    $dir = '' if $dir eq '.';
    status "checking $modified $_";
    if ($file eq '.picasa.ini' or $file eq 'Picasa.ini' or
	$file eq '.names.txt' or $file eq '.birthdays.txt') {
	push @ini, "$dir$file";	# update later after all pictures
	return;
    } elsif ($file =~ /^\..+/ or # ignore hidden files, and:
	     $file eq 'Originals' or
	     $file =~ /$conf->{reject}/) {
	status("rejecting $_\n");
	$File::Find::prune = 1;
	return;
    }
    # return;			# hack!!!! remove this!!!!!
    unless ($done == time) {
	$schema->txn_commit;
	status "checked $done";
	$schema->txn_begin;
	$done = time;
    }
    if (-f $_) {
	return unless $file =~ /$conf->{regex}/i;
	#	return unless $file =~ /$conf->{keep}/;
	my $key = $_;
	$key =~ s@\./@@;
	return unless -f $key and -s $key > 100;
	my $dir_id = &_savedirs($dir);
	my $row = $schema->resultset('Picture')->find_or_create(
	    { dir_id => $dir_id,
	      basename => $file },
	    );
	return if ($row->modified || 0) >= $modified; # unchanged
	my $info = $exiftool->ImageInfo($key) or return;
	return unless $info->{ImageWidth} and $info->{ImageHeight};
	my $pix = $info->{ImageWidth} * $info->{ImageHeight};
	if ($pix < $conf->{minpixels}) {
	    status("skipping too small $pix at $_\n");
	    return;
	}
	if (my $dur = $info->{Duration}) {
	    if (!/\.gif$/i or	# ignore duration of 1 frame gif
		($info->{FrameCount} and $info->{FrameCount} > 1)) {
		$row->duration($dur =~ /(\S+) s/ ? $1
			       : $dur =~ /(\d+):(\d\d):(\d\d)/
			       ? $1 * 3600 + $2 * 60 + $3
			       : $dur); # should never happen
	    }
	}
	my $or = $info->{Orientation} || '';
	my $rot = $or =~ /Rotate (\d+)/i ? $1 : $info->{Rotation} || 0;
	my $swap = $rot == 90 || $rot == 270 || 0;
	my $time = $info->{DateTimeOriginal} || $info->{DateCreated}
	|| $info->{CreateDate} || $info->{ModifyDate}
	|| $info->{FileModifyDate} || 0;
	$time =~ s/: /:0/g;	# fix corrupt: 2008:04:23 19:21: 4
	$time = str2time $time;
	$time ||= $modified;	# only if no exif of original time
	my @t = localtime $time;
	if ($t[5] < 66) { # hack!!! fix negative time from QuickTimeUTC
	    $t[5] += 66;  # year += 66
	    $time = timelocal(@t);
	}

	$row->time($time);
	$row->modified($modified);
	$row->bytes(-s $_);
	$row->rotation($rot);
	$row->width($swap ? $info->{ImageHeight} : $info->{ImageWidth});
	$row->height($swap ? $info->{ImageWidth} : $info->{ImageHeight});
	$row->caption($info->{'Caption-Abstract'}
		      || $info->{'Description'} || undef);
	$row->is_changed
	    ? $row->update
	    : $row->discard_changes;

	&_dirtimes($dir_id, $time);

	$vfs->savepathfile("/[Folders]/$dir", $row->file_id);

	$vfs->savepathfile("/[Timeline]/All Time/", $row->file_id);
	$vfs->savepathfile(strftime("/[Timeline]/Years/%Y/",
				    localtime $time), $row->file_id);
	$vfs->savepathfile(strftime("/[Timeline]/Months/%Y-%m-%b/",
				    localtime $time), $row->file_id);

	my %tags; map { $tags{$_}++ } split /,\s*/,
		      $info->{Keywords} || $info->{Subject} || '';
	for my $tag (keys %tags) {
	    my $rstag = $schema->resultset('Tag')->find_or_create(
		{ tag => $tag });
	    $schema->resultset('PictureTag')->find_or_create(
		{ tag_id => $rstag->tag_id,
		  file_id => $row->file_id });
	    $vfs->savepathfile("/[Tags]/$tag/", $row->file_id);
	}

    } elsif (-d $_) {
	# $db->{dirs}{$dir}{"$file/"} or
	#     $db->{dirs}{$dir}{"$file/"} = {};
    }
    #    $guard->commit;	       # DBIx::Class::Storage::TxnScopeGuard
    # unless ($db->{dir} and $db->{file}) {
    # 	my $tmp = $db->filter(qw(/));
    # 	$tmp and $tmp->{children} and $db->{dir} = $db->{file} = $tmp;
    # }
    &{$conf->{update}};
}

# remove records of deleted files, requires a stat of all files --
# TODO: maybe stat files only in dirs that changed !!!
sub cleanup {
    my $self = shift;
    $vfs->captions;		# move this somewhere?
    status "cleaning removed files from DB\n";
    my $tschema = $self->tschema;
    $schema->txn_begin; $tschema->txn_begin;
    my $rs = $schema->resultset('Picture');
    my $ts = $tschema->resultset('Thumb');

    while (my $pic = $rs->next) {
	$pic->file_id or next;	# skip special 0 which is all files of dir
	my $file = $pic->pathtofile or next;
	my $modified = -f $file ? (stat $file)[9] : time;
	# warn "testing $modified $file";
	my $thumbs = $ts->search( { file_id => $pic->file_id,
				    modified => {'<' => $modified} });
	# warn "removing ", $thumbs, " of ", $pic->file_id;
	$thumbs->delete;	# remove changed thumbnails
	unless ($done == time) {
	    $schema->txn_commit; $tschema->txn_commit;
	    status "checked $done";
	    $schema->txn_begin; $tschema->txn_begin;
	    $done = time;
	}
	-f $file and next;
#	warn "removing $file";
	$pic->delete;
    }
    $tschema->txn_commit;

    my $paths = $schema->resultset('Path'); # clean paths of no more pictures
    while (my $path = $paths->next) {
	my $pics = $schema->resultset('PathView')->search(
	    {path => { like => $path->path . '%'},
	     time => { '!=' => undef }});
	$pics->count and next;
#	warn "removing empty ", $path->path;
	$path->delete;
	unless ($done == time) {
	    $schema->txn_commit;
	    status "checked $done";
	    $schema->txn_begin;
	    $done = time;
	}
    }
    $schema->txn_commit;
}

# TODO: find and index duplicates
sub duplicates {
}

1;				# LPDB::Filesystem.pm

__END__

=head1 SEE ALSO

L<LPDB>, L<LPDB::Picasa>, L<lpgallery>

=head1 AUTHOR

Timothy D Witham <twitham@sbcglobal.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2013-2024 Timothy D Witham.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
