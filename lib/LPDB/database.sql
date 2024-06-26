-- LPDB: local picture metadata in sqlite

-- by twitham@sbcglobal.net, 2019/11

-- https://www.sqlitetutorial.net/sqlite-create-table/

-- this is per-connection so TODO: get LPDB to have this also:
PRAGMA foreign_keys = ON;

-- dbicdump automatically includes this documentation in the class output
CREATE TABLE IF NOT EXISTS table_comments (
   table_name TEXT PRIMARY KEY NOT NULL,
   comment_text TEXT); --  WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS column_comments (
   table_name TEXT NOT NULL,
   column_name TEXT NOT NULL,
   comment_text TEXT,
   PRIMARY KEY (table_name, column_name)); --  WITHOUT ROWID;

---------------------------------------- PICTURES
INSERT OR REPLACE INTO table_comments (table_name, comment_text) VALUES
   ('Pictures',	  'Picture files that hold images');

INSERT OR REPLACE INTO column_comments (table_name, column_name, comment_text) VALUES
   ('Pictures', 'basename', 'Base name to the image file contents'),
   ('Pictures', 'dir_id',   'ID of the directory of the file'),
   ('Pictures', 'bytes',    'Size of the image file in bytes'),
   ('Pictures', 'modified', 'Last modified timestamp of the image file'),
   ('Pictures', 'time',     'Time image was taken if known from EXIF, else file create or modify time'),
   ('Pictures', 'rotation', 'Orientation of the camera in degrees: 0, 90, 180, 270'),
   ('Pictures', 'width',    'Displayed horizontal width of the image in pixels, after rotation correction'),
   ('Pictures', 'height',   'Displayed vertical height of the image in pixels, after rotation correction'),
   ('Pictures', 'caption',  'EXIF caption or description'),
   ('Pictures', 'duration', 'video duration in seconds or undefined for pictures'),
   ('Pictures', 'stars',    'optional star rating'),
   ('Pictures', 'attrs',    'optional attribute string');

CREATE TABLE IF NOT EXISTS Pictures (
   file_id	INTEGER PRIMARY KEY NOT NULL, -- alias to fast: rowid, oid, _rowid_
   basename	TEXT NOT NULL,
   dir_id	INTEGER,
   bytes	INTEGER,
   modified	INTEGER,
   time		INTEGER,
   rotation	INTEGER DEFAULT 0,
   width	INTEGER,
   height	INTEGER,
   caption	TEXT,
   duration	REAL,
   stars	INTEGER,
   attrs	TEXT,
   FOREIGN KEY (dir_id)
      REFERENCES Directories (dir_id)
         ON DELETE CASCADE
         ON UPDATE CASCADE
   );

CREATE INDEX IF NOT EXISTS basename_index ON Pictures (basename);
CREATE INDEX IF NOT EXISTS caption_index ON Pictures (caption);
CREATE INDEX IF NOT EXISTS time_index ON Pictures (time);
CREATE INDEX IF NOT EXISTS bytes_index ON Pictures (bytes);

---------------------------------------- Directories of pictures
INSERT OR REPLACE INTO table_comments (table_name, comment_text) VALUES
   ('Directories', 'Physical collections of pictures');

INSERT OR REPLACE INTO column_comments (table_name, column_name, comment_text) VALUES
   ('Directories', 'directory', 'Physical path to a collection of pictures'),
   ('Directories', 'parent_id', 'ID of parent directory, 0 for / root'),
   ('Directories', 'begin',	'time of first picture in the directory'),
   ('Directories', 'end',	'time of last picture in the directory');
   
CREATE TABLE IF NOT EXISTS Directories (
   dir_id	INTEGER PRIMARY KEY NOT NULL,
   directory	TEXT UNIQUE NOT NULL,
   parent_id	INTEGER,
   begin	INTEGER,
   end		INTEGER
   );
CREATE INDEX IF NOT EXISTS dir_index ON Directories (directory);
CREATE INDEX IF NOT EXISTS dir_begin_index ON Directories (begin);
CREATE INDEX IF NOT EXISTS dir_end_index ON Directories (end);
INSERT OR REPLACE INTO Directories (dir_id, directory, parent_id) VALUES (1, '/', 0);

---------------------------------------- Virtual File System
INSERT OR REPLACE INTO table_comments (table_name, comment_text) VALUES
   ('Paths', 'Virtual logical collections of pictures');

INSERT OR REPLACE INTO column_comments (table_name, column_name, comment_text) VALUES
   ('Paths', 'path', 'Logical path to a collection of pictures'),
   ('Paths', 'parent_id', 'ID of parent path, 0 for / root');
   
CREATE TABLE IF NOT EXISTS Paths (
   path_id	INTEGER PRIMARY KEY NOT NULL,
   path		TEXT UNIQUE NOT NULL,
   parent_id	INTEGER
   );
CREATE INDEX IF NOT EXISTS path_index ON Paths (path);
INSERT OR REPLACE INTO Paths (path_id, path, parent_id) VALUES (1, '/', 0);

---------------------------------------- PICTURE PATH many2many
INSERT OR REPLACE INTO table_comments (table_name, comment_text) VALUES
   ('PicturePath', 'Joins many pictures to many virtual paths');
CREATE TABLE IF NOT EXISTS PicturePath (
   file_id INTEGER,
   path_id INTEGER,
   PRIMARY KEY (file_id, path_id),
   FOREIGN KEY (file_id) 
      REFERENCES Pictures (file_id)
         ON DELETE CASCADE
         ON UPDATE CASCADE,
   FOREIGN KEY (path_id) 
      REFERENCES Paths (path_id) 
         ON DELETE CASCADE 
         ON UPDATE CASCADE
) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS pp_pid_index ON PicturePath (path_id, file_id);
CREATE INDEX IF NOT EXISTS pp_fid_index ON PicturePath (file_id, path_id);

---------------------------------------- TAGS
INSERT OR REPLACE INTO table_comments (table_name, comment_text) VALUES
   ('Tags', 'Tags in pictures (EXIF keywords or subject)');

INSERT OR REPLACE INTO column_comments (table_name, column_name, comment_text) VALUES
   ('Tags', 'tag', 'Unique text of one tag');
   
CREATE TABLE IF NOT EXISTS Tags (
   tag_id	INTEGER PRIMARY KEY NOT NULL,
   tag		TEXT UNIQUE NOT NULL);

CREATE UNIQUE INDEX IF NOT EXISTS tag_index ON Tags (tag);

---------------------------------------- PICTURE TAGS many2many
INSERT OR REPLACE INTO table_comments (table_name, comment_text) VALUES
   ('PictureTag', 'Joins many pictures to many tags');
CREATE TABLE IF NOT EXISTS PictureTag (
   file_id INTEGER,
   tag_id INTEGER,
   PRIMARY KEY (file_id, tag_id),
   FOREIGN KEY (file_id) 
      REFERENCES Pictures (file_id)
         ON DELETE CASCADE
         ON UPDATE CASCADE,
   FOREIGN KEY (tag_id) 
      REFERENCES Tags (tag_id) 
         ON DELETE CASCADE 
         ON UPDATE CASCADE
) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS pt_tid_index ON PictureTag (tag_id, file_id);
CREATE INDEX IF NOT EXISTS pt_fid_index ON PictureTag (file_id, tag_id);

---------------------------------------- ALBUMS
INSERT OR REPLACE INTO table_comments (table_name, comment_text) VALUES
   ('Albums', 'Logical collections of pictures');

INSERT OR REPLACE INTO column_comments (table_name, column_name, comment_text) VALUES
   ('Albums', 'name',        'Name of the Photo Album'),
   ('Albums', 'date',        'Date of the Photo Album'),
   ('Albums', 'place',       'Place Taken (optional)'),
   ('Albums', 'description', 'Description (optional)');
   
CREATE TABLE IF NOT EXISTS Albums (
   album_id	INTEGER PRIMARY KEY NOT NULL,
   name		TEXT UNIQUE NOT NULL,
   date		INTEGER,	-- YYMMDD, or epoch, or DateTime?
   place	TEXT,
   description	TEXT
   );

CREATE UNIQUE INDEX IF NOT EXISTS album_name_index ON Albums (name);
CREATE INDEX IF NOT EXISTS album_place_index ON Albums (place);
CREATE INDEX IF NOT EXISTS album_description_index ON Albums (description);

---------------------------------------- PICTURE ALBUM many2many
INSERT OR REPLACE INTO table_comments (table_name, comment_text) VALUES
   ('PictureAlbum', 'Joins many pictures to many albums');
CREATE TABLE IF NOT EXISTS PictureAlbum (
   file_id INTEGER,
   album_id INTEGER,
   PRIMARY KEY (file_id, album_id),
   FOREIGN KEY (file_id) 
      REFERENCES Pictures (file_id)
         ON DELETE CASCADE
         ON UPDATE CASCADE,
   FOREIGN KEY (album_id) 
      REFERENCES Albums (album_id) 
         ON DELETE CASCADE 
         ON UPDATE CASCADE
) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS pa_aid_index ON PictureAlbum (album_id, file_id);
CREATE INDEX IF NOT EXISTS pa_fid_index ON PictureAlbum (file_id, album_id);

---------------------------------------- CONTACTS
INSERT OR REPLACE INTO table_comments (table_name, comment_text) VALUES
   ('Contacts', 'Known people in pictures');

INSERT OR REPLACE INTO column_comments (table_name, column_name, comment_text) VALUES
   ('Contacts', 'name',		'Name of the person, required'),
   ('Contacts', 'email',        'Optional email address'),
   ('Contacts', 'birth',        'Optional time of birth');

CREATE TABLE IF NOT EXISTS Contacts (
   contact_id	INTEGER PRIMARY KEY NOT NULL,
   name		TEXT UNIQUE NOT NULL,
   email	TEXT,
   birth	INTEGER
   );

CREATE UNIQUE INDEX IF NOT EXISTS contact_name_index ON Contacts (name);
CREATE INDEX IF NOT EXISTS contact_email_index ON Contacts (email);
INSERT OR REPLACE INTO Contacts (contact_id, name, email) VALUES
   (0, '', '');

---------------------------------------- KEYVALUE
INSERT OR REPLACE INTO table_comments (table_name, comment_text) VALUES
   ('NameValue', 'Name / Value data store');

INSERT OR REPLACE INTO column_comments (table_name, column_name, comment_text) VALUES
   ('NameValue', 'name',	'Name of the key'),
   ('NameValue', 'value',	'Value of the key');

CREATE TABLE IF NOT EXISTS NameValue (
   name_id	INTEGER PRIMARY KEY NOT NULL,
   name		TEXT UNIQUE NOT NULL,
   value	TEXT
   );

CREATE UNIQUE INDEX IF NOT EXISTS nv_name_index ON NameValue (name);
