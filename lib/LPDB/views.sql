-- This magic single all in one view completes the many-to-many
-- relationships.  This enables navigate/filter/group/sort by
-- anything!  Query code must be careful to group_by what is needed

DROP VIEW IF EXISTS PathView;

CREATE VIEW PathView AS
   SELECT
      Paths.*,
      Pictures.*,
      (Pictures.width * Pictures.height) AS pixels,
      (Directories.directory || Pictures.basename) AS filename,
      Tags.*
   FROM
      Paths
   LEFT JOIN PicturePath ON Paths.path_id = PicturePath.path_id
   LEFT JOIN Pictures ON Pictures.file_id = PicturePath.file_id
   LEFT JOIN Directories ON Pictures.dir_id = Directories.dir_id
   LEFT JOIN PictureTag ON Pictures.file_id = PictureTag.file_id
   LEFT JOIN Tags ON Tags.tag_id = PictureTag.tag_id;
   -- TODO: add joins to picasa metadata here

-- experimental stats in 1 view
-- TODO: fix bug that files are counted multiple times
DROP VIEW IF EXISTS PathStats;

CREATE VIEW PathStats AS
   SELECT
      Paths.path_id AS path_id,
      COUNT(Pictures.file_id) AS files,
      MIN(Pictures.time) AS mintime,
      MAX(Pictures.time) AS maxtime,
      SUM(Pictures.bytes) AS totalbytes,
      SUM(Pictures.width * Pictures.height) AS totalpixels
   FROM
      Paths
   LEFT JOIN PicturePath ON Paths.path_id = PicturePath.path_id
   LEFT JOIN Pictures ON Pictures.file_id = PicturePath.file_id;

-- CREATE VIEW PathStats AS
--    SELECT
--       path_id,
--       COUNT(file_id) AS files,
--       MIN(time) AS mintime,
--       MAX(time) AS maxtime,
--       TOTAL(bytes) AS totalbytes,
--       TOTAL(pixels) AS totalpixels
--    FROM
--       PathView
--    GROUP BY path_id;

-- original experimental views below no longer used
-- TODO: remove all this if it is not valuable

DROP VIEW IF EXISTS AllView;

DROP VIEW IF EXISTS PicturePathView;

-- CREATE VIEW PicturePathView AS
--    SELECT
--       path.path AS path,
--       pictures.*
--    FROM
--       pictures, path, picture_path
--    WHERE
--       pictures.file_id = picture_path.file_id
--       AND
--       path.path_id = picture_path.path_id;

DROP VIEW IF EXISTS PictureTagView;

-- CREATE VIEW PictureTagView AS
--    SELECT
--       tags.string as string,
--       pictures.*
--    FROM
--       pictures, tags, picture_tag
--    WHERE
--       pictures.file_id = picture_tag.file_id
--       AND
--       tags.tag_id = picture_tag.tag_id;

DROP VIEW IF EXISTS PathTagView;

-- CREATE VIEW PathTagView AS
--    SELECT
--       tags.string as string,
--       path.path AS path,
--       pictures.filename AS filename
--    FROM
--       pictures, tags, picture_tag, picture_path, path
--    WHERE
--       pictures.file_id = picture_tag.file_id
--       AND
--       tags.tag_id = picture_tag.tag_id
--       AND
--       pictures.file_id = picture_path.file_id
--       AND
--       path.path_id = picture_path.path_id;
