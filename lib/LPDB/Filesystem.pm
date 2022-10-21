package LPDB::Filesystem;

=head1 NAME

LPDB::Filesystem - update sqlite from local picture metadata

=cut

use strict;
use warnings;
use File::Find;
use Date::Parse;
use POSIX qw/strftime/;
use Image::ExifTool qw(:Public);
use LPDB::Schema;
use LPDB::VFS;
#use LPDB::Picasa;		# !!!TODO
use base 'Exporter::Tiny';
our @EXPORT = qw(update create cleanup);

my $exiftool;	  # global hacks for File::Find !!!  We'll never
my $schema;	  # find more than once per process, so this is OK.
my $vfs;	  # LPDB::VFS database methods
our $conf;
my $done = 0;			# records processed
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
    # print STDERR "\r$done    @_      ";
    print STDERR "\r\e[J$done    @_      ";
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
	$conf->{all} = $regex;
    }
    # warn "self=$self, conf=$conf, reject=$conf->{reject}";
    # warn "reject: ", $self->conf('reject');
    unless ($vfs) {
	$vfs = new LPDB::VFS($self);
    }
    unless ($exiftool) {
	$exiftool = new Image::ExifTool;
	$exiftool->Options(FastScan => 1);
    }
    status "update @dirs";
    $schema->txn_begin;
    find ({ no_chdir => 1,
	    preprocess => sub { sort @_ },
	    wanted => \&_wanted,
#	    postprocess => $conf->{update},
	  }, @dirs);
    $schema->txn_commit;
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
	    status ' ' x 60, "saving dir $this";
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
    status "checking: $modified $_";
    if ($file eq '.picasa.ini' or $file eq 'Picasa.ini') {
	# my $tmp = LPDB::Picasa::readini($_);
	# use Data::Dumper;
	# print Dumper $tmp;
	# &_understand($db, _readfile($_));
	# $db->{dirs}{$dir}{'<<updated>>'} = $modified;
	return;
    } elsif ($file =~ /^\..+/ or # ignore hidden files, and:
	     $file eq 'Originals' or
	     $file =~ /$conf->{reject}/) { 
	$File::Find::prune = 1;
	return;
    }
    #    my $guard = $schema->txn_scope_guard; # DBIx::Class::Storage::TxnScopeGuard
    unless (++$done % 100) {	# fix this!!! make configurable??...
	$schema->txn_commit;
	status "committed $done";
	$schema->txn_begin;
    }
    if (-f $_) {
	return unless $file =~ /$conf->{all}/i;
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
	if (my $dur = $info->{Duration}) {
	    if (!/\.gif$/i or	# ignore duration of 1 frame gif
		($info->{FrameCount} and $info->{FrameCount} > 1)) {
		$row->duration($dur =~ /(\S+) s/ ? $1
			       : $dur =~ /(\d+):(\d\d):(\d\d)$/
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

	# $vfs->savepathfile("/[Captions]/", $row->file_id)
	#     if $row->caption;

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

	# 	$this->{face}	= $db->faces($dir, $file, $this->{rot}); # picasa data for this pic
	# 	$this->{album}	= $db->albums($dir, $file);
	# 	$this->{stars}	= $db->star($dir, $file);
	# 	$this->{uploads} = $db->uploads($dir, $file);
	# 	$this->{faces}	= keys %{$this->{face}} ? 1 : 0; # boolean attributes
	# 	$this->{albums}	= keys %{$this->{album}} ? 1 : 0;

	# 	$this->{time} =~ /0000/ and
	# 	    warn "bogus time in $_: $this->{time}\n";

	# 	# add virtual folders of stars, tags, albums, people
	# 	$this->{stars} and
	# 	    $db->_addpic2path("/[Stars]/$year/$vname", $key);

	# 	for my $id (keys %{$this->{album}}) { # named user albums
	# 	    next unless my $name = $db->{album}{$id}{name};
	# 	    # putting year in this path would cause albums that span
	# 	    # year boundary to be split to multiple places...
	# 	    $db->_addpic2path("/[Albums]/$name/$vname", $key);
	# 	}

	# 	# add faces / people
	# 	for my $id (keys %{$this->{face}}) {
	# 	    next unless my $name = $db->contact2person($id);
	# 	    $db->_addpic2path("/[People]/$name/$year/$vname", $key);
	# 	}

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
    status "cleaning removed files from DB";
    my $tschema = $self->tschema;
    $schema->txn_begin; $tschema->txn_begin;
    my $rs = $schema->resultset('Picture');
    my $ts = $tschema->resultset('Thumb');
    while (my $pic = $rs->next) {
	my $file = $pic->pathtofile or next;
	my $modified = (stat $file)[9]; # remove changed thumbnails
	if (my $thumbs = $ts->search({ file_id => $pic->file_id, $modified
					   ? (modified => {'<' => $modified})
					   : () })) {
	    # warn "removing $thumbs of ", $pic->file_id;
	    $thumbs->delete_all;
	}
	-f $file and next;
#	warn "removing $file";
	$pic->delete;
	unless (++$done % 100) { # fix this!!! make configurable??...
	    $schema->txn_commit; $tschema->txn_commit;
	    status "committed $done";
	    $schema->txn_begin; $tschema->txn_begin;
	}
    }
    my $paths = $schema->resultset('Path'); # clean paths of no more pictures
    while (my $path = $paths->next) {
	my $pics = $schema->resultset('PathView')->search(
	    {path => { like => $path->path . '%'},
	     time => { '!=' => undef }});
	$pics->count and next;
#	warn "removing empty ", $path->path;
	$path->delete;
	unless (++$done % 100) { # fix this!!! make configurable??...
	    $schema->txn_commit; $tschema->txn_commit;
	    status "committed $done";
	    $schema->txn_begin; $tschema->txn_begin;
	}
    }
    $schema->txn_commit; $tschema->txn_commit;
}

# TODO: find and index duplicates
sub duplicates {
}

1;				# LPDB::Filesystem.pm
