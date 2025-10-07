/*
  usp_GctIntersections (SQL Server 2019)
  Computes intersections of a great-circle path (A->B) with integer latitude parallels
  and integer longitude meridians. Includes endpoints, prints numeric coordinates
  and formatted labels with negative-integer adjustment.

  Usage example (matches Python example):
    EXEC dbo.usp_GctIntersections
      @Lat1 = 21.2, @Lon1 = -60.1,
      @Lat2 = 18.7, @Lon2 = -58.4,
      @NumPoints = 400,
      @SearchAllLongitudes = 1;
*/

GO
IF OBJECT_ID('dbo.usp_GctIntersections', 'P') IS NOT NULL
  DROP PROCEDURE dbo.usp_GctIntersections;
GO
CREATE PROCEDURE dbo.usp_GctIntersections
  @Lat1 float,
  @Lon1 float,
  @Lat2 float,
  @Lon2 float,
  @NumPoints int = 200,              -- number of intermediate points (densification)
  @SearchAllLongitudes bit = 1       -- 1: scan -180..180, 0: restrict to path lon bounds
AS
BEGIN
  SET NOCOUNT ON;

  -- Normalize longitude to [-180, 180]
  DECLARE @NormalizeLon1 float = ((@Lon1 + 180.0) - FLOOR((@Lon1 + 180.0) / 360.0) * 360.0) - 180.0;
  DECLARE @NormalizeLon2 float = ((@Lon2 + 180.0) - FLOOR((@Lon2 + 180.0) / 360.0) * 360.0) - 180.0;

  -- Convert to radians
  DECLARE @DegToRad float = PI() / 180.0;
  DECLARE @RadToDeg float = 180.0 / PI();
  DECLARE @phi1 float = @Lat1 * @DegToRad;
  DECLARE @lam1 float = @Lon1 * @DegToRad;
  DECLARE @phi2 float = @Lat2 * @DegToRad;
  DECLARE @lam2 float = @Lon2 * @DegToRad;

  -- Unit vectors for endpoints
  DECLARE @cphi1 float = COS(@phi1), @sphi1 float = SIN(@phi1);
  DECLARE @cphi2 float = COS(@phi2), @sphi2 float = SIN(@phi2);
  DECLARE @x1 float = @cphi1 * COS(@lam1);
  DECLARE @y1 float = @cphi1 * SIN(@lam1);
  DECLARE @z1 float = @sphi1;
  DECLARE @x2 float = @cphi2 * COS(@lam2);
  DECLARE @y2 float = @cphi2 * SIN(@lam2);
  DECLARE @z2 float = @sphi2;

  DECLARE @dot float = @x1 * @x2 + @y1 * @y2 + @z1 * @z2;
  -- Clamp dot to [-1, 1] to avoid numeric issues
  IF @dot > 1.0 SET @dot = 1.0;
  IF @dot < -1.0 SET @dot = -1.0;

  DECLARE @theta float = ACOS(@dot);
  DECLARE @sinTheta float = SIN(@theta);
  DECLARE @nearZero bit = CASE WHEN ABS(@sinTheta) < 1e-12 THEN 1 ELSE 0 END;

  -- Collect path points (endpoints + @NumPoints slerp points)
  DECLARE @Points TABLE (
    Position int PRIMARY KEY,
    Lat float NOT NULL,
    Lon float NOT NULL -- normalized [-180, 180]
  );

  INSERT INTO @Points(Position, Lat, Lon)
  VALUES (0, @Lat1, @NormalizeLon1);

  DECLARE @i int = 1;
  DECLARE @n int = @NumPoints;
  WHILE @i <= @n
  BEGIN
    DECLARE @t float = CONVERT(float, @i) / (CONVERT(float, @n) + 1.0);

    DECLARE @w1 float, @w2 float;
    IF @nearZero = 1
    BEGIN
      -- Points nearly identical or antipodal; fall back to linear interpolation in 3D
      SET @w1 = 1.0 - @t;
      SET @w2 = @t;
    END
    ELSE
    BEGIN
      SET @w1 = SIN((1.0 - @t) * @theta) / NULLIF(@sinTheta, 0.0);
      SET @w2 = SIN(@t * @theta) / NULLIF(@sinTheta, 0.0);
    END

    DECLARE @xs float = @w1 * @x1 + @w2 * @x2;
    DECLARE @ys float = @w1 * @y1 + @w2 * @y2;
    DECLARE @zs float = @w1 * @z1 + @w2 * @z2;

    -- Normalize to unit vector (guard against accumulation of error)
    DECLARE @norm float = SQRT(@xs * @xs + @ys * @ys + @zs * @zs);
    IF @norm > 0.0
    BEGIN
      SET @xs = @xs / @norm;
      SET @ys = @ys / @norm;
      SET @zs = @zs / @norm;
    END

    DECLARE @lat float = ATN2(@zs, SQRT(@xs * @xs + @ys * @ys)) * @RadToDeg;
    DECLARE @lon float = ATN2(@ys, @xs) * @RadToDeg;
    DECLARE @lonNorm float = ((@lon + 180.0) - FLOOR((@lon + 180.0) / 360.0) * 360.0) - 180.0;

    INSERT INTO @Points(Position, Lat, Lon)
    VALUES (@i, @lat, @lonNorm);

    SET @i += 1;
  END

  INSERT INTO @Points(Position, Lat, Lon)
  VALUES (@n + 1, @Lat2, @NormalizeLon2);

  -- Build segments between consecutive points
  DECLARE @Segments TABLE (
    Position int PRIMARY KEY,
    Lat1 float NOT NULL,
    Lon1 float NOT NULL,
    Lat2 float NOT NULL,
    Lon2 float NOT NULL
  );

  INSERT INTO @Segments(Position, Lat1, Lon1, Lat2, Lon2)
  SELECT p1.Position, p1.Lat, p1.Lon, p2.Lat, p2.Lon
  FROM @Points p1
  JOIN @Points p2 ON p2.Position = p1.Position + 1;

  -- Results table (rounded to 9 decimals for dedup), plus labels
  DECLARE @Results TABLE (
    Lat numeric(18,9) NOT NULL,
    Lon numeric(18,9) NOT NULL,
    PRIMARY KEY (Lat, Lon)
  );

  -- Add endpoints
  INSERT INTO @Results(Lat, Lon)
  SELECT CAST(ROUND(Lat, 9) AS numeric(18,9)), CAST(ROUND(Lon, 9) AS numeric(18,9))
  FROM (VALUES (@Lat1, @NormalizeLon1), (@Lat2, @NormalizeLon2)) v(Lat, Lon)
  WHERE NOT EXISTS (
    SELECT 1 FROM @Results r
    WHERE r.Lat = CAST(ROUND(v.Lat, 9) AS numeric(18,9))
      AND r.Lon = CAST(ROUND(v.Lon, 9) AS numeric(18,9))
  );

  -- Latitude intersections (scan integer lat from floor(min) to ceil(max))
  DECLARE @LatMin float = (SELECT FLOOR(MIN(Lat)) FROM @Points);
  DECLARE @LatMax float = (SELECT CEILING(MAX(Lat)) FROM @Points);

  DECLARE @kLat int = CONVERT(int, @LatMin);
  WHILE @kLat <= CONVERT(int, @LatMax)
  BEGIN
    ;WITH Seg AS (
      SELECT s.Position, s.Lat1, s.Lon1, s.Lat2, s.Lon2,
             s.Lon2 - s.Lon1 AS DeltaLon
      FROM @Segments s
      WHERE s.Lat1 <> s.Lat2
        AND ((@kLat BETWEEN s.Lat1 AND s.Lat2) OR (@kLat BETWEEN s.Lat2 AND s.Lat1))
    ), Adj AS (
      SELECT Position, Lat1, Lon1,
             Lat2,
             CASE WHEN DeltaLon > 180.0 THEN Lon2 - 360.0
                  WHEN DeltaLon < -180.0 THEN Lon2 + 360.0
                  ELSE Lon2 END AS Lon2Adj
      FROM Seg
    ), Interp AS (
      SELECT
        CAST(ROUND(CONVERT(float, @kLat), 9) AS numeric(18,9)) AS LatInt,
        CAST(ROUND(
          (
            Lon1 + ( (Lon2Adj - Lon1) * ((CONVERT(float, @kLat) - Lat1) / NULLIF(Lat2 - Lat1, 0.0)) )
          ), 9) AS numeric(18,9)) AS LonInt
      FROM Adj
    ), DistinctCands AS (
      SELECT DISTINCT LatInt AS Lat, 
             CAST(ROUND( ((LonInt + 180.0) - FLOOR((LonInt + 180.0)/360.0) * 360.0) - 180.0, 9) AS numeric(18,9)) AS Lon
      FROM Interp
    ), NewRows AS (
      SELECT d.Lat, d.Lon
      FROM DistinctCands d
      EXCEPT
      SELECT r.Lat, r.Lon FROM @Results r
    )
    INSERT INTO @Results(Lat, Lon)
    SELECT Lat, Lon FROM NewRows;

    SET @kLat += 1;
  END

  -- Longitude intersections (scan integer lon)
  DECLARE @LonMin float, @LonMax float, @LonStart int, @LonEnd int;
  IF @SearchAllLongitudes = 1
  BEGIN
    SET @LonStart = -180; SET @LonEnd = 180;
  END
  ELSE
  BEGIN
    SELECT @LonMin = FLOOR(MIN(Lon)), @LonMax = CEILING(MAX(Lon)) FROM @Points;
    IF (@LonMax - @LonMin) > 180.0
    BEGIN
      SET @LonStart = -180; SET @LonEnd = 180;
    END
    ELSE
    BEGIN
      SET @LonStart = CONVERT(int, @LonMin) - 1; 
      SET @LonEnd   = CONVERT(int, @LonMax) + 1;
    END
  END

  DECLARE @kLon int = @LonStart;
  WHILE @kLon <= @LonEnd
  BEGIN
    ;WITH Seg AS (
      SELECT s.Position, s.Lat1, s.Lon1, s.Lat2, s.Lon2,
             s.Lon2 - s.Lon1 AS DeltaLon
      FROM @Segments s
      WHERE s.Lon1 <> s.Lon2 -- exclude perfectly vertical const-lon segments
    ), Adj AS (
      SELECT Position, Lat1, Lon1, Lat2,
             CASE WHEN DeltaLon > 180.0 THEN Lon2 - 360.0
                  WHEN DeltaLon < -180.0 THEN Lon2 + 360.0
                  ELSE Lon2 END AS Lon2Adj
      FROM Seg
    ), RangeVals AS (
      SELECT Position, Lat1, Lon1, Lat2, Lon2Adj,
             CASE WHEN Lon1 <= Lon2Adj THEN Lon1 ELSE Lon2Adj END AS RMin,
             CASE WHEN Lon1 >= Lon2Adj THEN Lon1 ELSE Lon2Adj END AS RMax
      FROM Adj
    ), WhichK AS (
      SELECT Position, Lat1, Lon1, Lat2, Lon2Adj, RMin, RMax,
             CASE 
               WHEN CONVERT(float, @kLon) BETWEEN RMin AND RMax THEN CONVERT(float, @kLon)
               WHEN CONVERT(float, @kLon) + 360.0 BETWEEN RMin AND RMax THEN CONVERT(float, @kLon) + 360.0
               WHEN CONVERT(float, @kLon) - 360.0 BETWEEN RMin AND RMax THEN CONVERT(float, @kLon) - 360.0
               ELSE NULL
             END AS KUse
      FROM RangeVals
    ), Interp AS (
      SELECT 
        CAST(ROUND(
          (Lat1 + ((Lat2 - Lat1) * ((KUse - Lon1) / NULLIF(Lon2Adj - Lon1, 0.0)))),
          9
        ) AS numeric(18,9)) AS LatInt,
        CAST(ROUND(CONVERT(float, @kLon), 9) AS numeric(18,9)) AS LonInt
      FROM WhichK
      WHERE KUse IS NOT NULL
    ), DistinctCands AS (
      SELECT DISTINCT LatInt AS Lat,
             CAST(ROUND( ((LonInt + 180.0) - FLOOR((LonInt + 180.0)/360.0) * 360.0) - 180.0, 9) AS numeric(18,9)) AS Lon
      FROM Interp
    ), NewRows AS (
      SELECT d.Lat, d.Lon
      FROM DistinctCands d
      EXCEPT
      SELECT r.Lat, r.Lon FROM @Results r
    )
    INSERT INTO @Results(Lat, Lon)
    SELECT Lat, Lon FROM NewRows;

    SET @kLon += 1;
  END

  -- Final output with labels
  ;WITH Labeled AS (
    SELECT 
      r.Lat AS Latitude,
      r.Lon AS Longitude,
      -- Adjust integer negative by subtracting 1 for labeling
      CASE WHEN r.Lat = CAST(FLOOR(r.Lat) AS numeric(18,9)) AND r.Lat < 0 THEN r.Lat - 1 ELSE r.Lat END AS LatForLabel,
      CASE WHEN r.Lon = CAST(FLOOR(r.Lon) AS numeric(18,9)) AND r.Lon < 0 THEN r.Lon - 1 ELSE r.Lon END AS LonForLabel
    FROM @Results r
  )
  SELECT 
    Latitude,
    Longitude,
    CASE WHEN LatForLabel >= 0 THEN N'N' + CAST(CAST(FLOOR(LatForLabel) AS int) AS nvarchar(8))
         ELSE N'S' + CAST(ABS(CAST(FLOOR(LatForLabel) AS int)) AS nvarchar(8)) END AS LatitudeLabel,
    CASE WHEN LonForLabel >= 0 THEN N'E' + CAST(CAST(FLOOR(LonForLabel) AS int) AS nvarchar(8))
         ELSE N'W' + CAST(ABS(CAST(FLOOR(LonForLabel) AS int)) AS nvarchar(8)) END AS LongitudeLabel
  FROM Labeled
  ORDER BY Latitude, Longitude;
END
GO
