-- GCT Intersections - MS SQL Server 2019 Stored Procedure
-- Computes intersections of great-circle arc between two points with integer parallels and meridians

USE [YourDatabaseName] -- Replace with your database name
GO

-- Helper function to normalize longitude to [-180, 180]
CREATE OR ALTER FUNCTION dbo.NormalizeLongitude(@lon FLOAT)
RETURNS FLOAT
AS
BEGIN
    RETURN ((@lon + 180.0) % 360.0) - 180.0
END
GO

-- Helper function to calculate great circle distance and bearing
CREATE OR ALTER FUNCTION dbo.CalculateGreatCircleBearing(@lat1 FLOAT, @lon1 FLOAT, @lat2 FLOAT, @lon2 FLOAT)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        @lat1 as lat1, @lon1 as lon1, @lat2 as lat2, @lon2 as lon2,
        -- Convert to radians
        RADIANS(@lat1) as lat1_rad, RADIANS(@lon1) as lon1_rad,
        RADIANS(@lat2) as lat2_rad, RADIANS(@lon2) as lon2_rad,
        -- Calculate bearing
        ATAN2(
            SIN(RADIANS(@lon2 - @lon1)) * COS(RADIANS(@lat2)),
            COS(RADIANS(@lat1)) * SIN(RADIANS(@lat2)) - 
            SIN(RADIANS(@lat1)) * COS(RADIANS(@lat2)) * COS(RADIANS(@lon2 - @lon1))
        ) as bearing_rad,
        -- Calculate distance
        ACOS(
            SIN(RADIANS(@lat1)) * SIN(RADIANS(@lat2)) + 
            COS(RADIANS(@lat1)) * COS(RADIANS(@lat2)) * COS(RADIANS(@lon2 - @lon1))
        ) as distance_rad
)
GO

-- Function to calculate point on great circle at given fraction
CREATE OR ALTER FUNCTION dbo.PointOnGreatCircle(@lat1 FLOAT, @lon1 FLOAT, @lat2 FLOAT, @lon2 FLOAT, @fraction FLOAT)
RETURNS TABLE
AS
RETURN
(
    WITH gc AS (
        SELECT * FROM dbo.CalculateGreatCircleBearing(@lat1, @lon1, @lat2, @lon2)
    )
    SELECT 
        ASIN(
            SIN(gc.lat1_rad) * COS(gc.distance_rad * @fraction) + 
            COS(gc.lat1_rad) * SIN(gc.distance_rad * @fraction) * COS(gc.bearing_rad)
        ) as lat_rad,
        gc.lon1_rad + ATAN2(
            SIN(gc.bearing_rad) * SIN(gc.distance_rad * @fraction) * COS(gc.lat1_rad),
            COS(gc.distance_rad * @fraction) - SIN(gc.lat1_rad) * SIN(ASIN(
                SIN(gc.lat1_rad) * COS(gc.distance_rad * @fraction) + 
                COS(gc.lat1_rad) * SIN(gc.distance_rad * @fraction) * COS(gc.bearing_rad)
            ))
        ) as lon_rad
    FROM gc
)
GO

-- Function to find intersection with latitude parallel
CREATE OR ALTER FUNCTION dbo.IntersectWithLatitude(@lat1 FLOAT, @lon1 FLOAT, @lat2 FLOAT, @lon2 FLOAT, @target_lat FLOAT)
RETURNS TABLE
AS
RETURN
(
    WITH gc AS (
        SELECT * FROM dbo.CalculateGreatCircleBearing(@lat1, @lon1, @lat2, @lon2)
    ),
    target_lat_rad AS (
        SELECT RADIANS(@target_lat) as target_lat_rad
    )
    SELECT 
        @target_lat as lat,
        dbo.NormalizeLongitude(DEGREES(
            gc.lon1_rad + ATAN2(
                SIN(gc.bearing_rad) * COS(target_lat_rad.target_lat_rad) * 
                SQRT(1 - POWER((SIN(target_lat_rad.target_lat_rad) - SIN(gc.lat1_rad) * COS(gc.distance_rad)) / 
                     (COS(gc.lat1_rad) * SIN(gc.distance_rad)), 2)),
                COS(gc.distance_rad) - SIN(gc.lat1_rad) * SIN(target_lat_rad.target_lat_rad)
            )
        )) as lon
    FROM gc, target_lat_rad
    WHERE ABS(COS(gc.lat1_rad) * COS(gc.lat2_rad) * SIN(RADIANS(@lon2 - @lon1))) > 0.000001 -- Avoid division by zero
)
GO

-- Function to find intersection with longitude meridian
CREATE OR ALTER FUNCTION dbo.IntersectWithLongitude(@lat1 FLOAT, @lon1 FLOAT, @lat2 FLOAT, @lon2 FLOAT, @target_lon FLOAT)
RETURNS TABLE
AS
RETURN
(
    WITH gc AS (
        SELECT * FROM dbo.CalculateGreatCircleBearing(@lat1, @lon1, @lat2, @lon2)
    ),
    target_lon_rad AS (
        SELECT RADIANS(@target_lon) as target_lon_rad
    )
    SELECT 
        ASIN(
            SIN(gc.lat1_rad) * COS(gc.distance_rad) + 
            COS(gc.lat1_rad) * SIN(gc.distance_rad) * COS(gc.bearing_rad)
        ) as lat_rad,
        @target_lon as lon
    FROM gc, target_lon_rad
    WHERE ABS(SIN(gc.bearing_rad)) > 0.000001 -- Avoid division by zero
)
GO

-- Main stored procedure for GCT intersections
CREATE OR ALTER PROCEDURE dbo.GCT_Intersections
    @lat1 FLOAT,
    @lon1 FLOAT,
    @lat2 FLOAT,
    @lon2 FLOAT,
    @npts INT = 200,
    @search_all_longitudes BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create temporary table to store results
    CREATE TABLE #Results (
        lat FLOAT,
        lon FLOAT,
        lat_label NVARCHAR(10),
        lon_label NVARCHAR(10)
    );
    
    -- Add start and end points
    INSERT INTO #Results (lat, lon, lat_label, lon_label)
    VALUES 
        (@lat1, @lon1, 
         CASE WHEN @lat1 >= 0 THEN CONCAT('N', FLOOR(@lat1)) ELSE CONCAT('S', FLOOR(ABS(@lat1))) END,
         CASE WHEN @lon1 >= 0 THEN CONCAT('E', FLOOR(@lon1)) ELSE CONCAT('W', FLOOR(ABS(@lon1))) END),
        (@lat2, @lon2,
         CASE WHEN @lat2 >= 0 THEN CONCAT('N', FLOOR(@lat2)) ELSE CONCAT('S', FLOOR(ABS(@lat2))) END,
         CASE WHEN @lon2 >= 0 THEN CONCAT('E', FLOOR(@lon2)) ELSE CONCAT('W', FLOOR(ABS(@lon2))) END);
    
    -- Calculate latitude range
    DECLARE @lat_min INT = FLOOR(LEAST(@lat1, @lat2));
    DECLARE @lat_max INT = CEILING(GREATEST(@lat1, @lat2));
    
    -- Find intersections with latitude parallels
    DECLARE @lat INT = @lat_min;
    WHILE @lat <= @lat_max
    BEGIN
        INSERT INTO #Results (lat, lon, lat_label, lon_label)
        SELECT 
            ROUND(lat, 9) as lat,
            ROUND(lon, 9) as lon,
            CASE WHEN lat >= 0 THEN CONCAT('N', FLOOR(lat)) ELSE CONCAT('S', FLOOR(ABS(lat))) END as lat_label,
            CASE WHEN lon >= 0 THEN CONCAT('E', FLOOR(lon)) ELSE CONCAT('W', FLOOR(ABS(lon))) END as lon_label
        FROM dbo.IntersectWithLatitude(@lat1, @lon1, @lat2, @lon2, @lat)
        WHERE lat IS NOT NULL AND lon IS NOT NULL;
        
        SET @lat = @lat + 1;
    END;
    
    -- Calculate longitude range
    DECLARE @lon_min INT, @lon_max INT;
    IF @search_all_longitudes = 1
    BEGIN
        SET @lon_min = -180;
        SET @lon_max = 180;
    END
    ELSE
    BEGIN
        SET @lon_min = FLOOR(LEAST(@lon1, @lon2));
        SET @lon_max = CEILING(GREATEST(@lon1, @lon2));
        IF @lon_max - @lon_min > 180
        BEGIN
            SET @lon_min = -180;
            SET @lon_max = 180;
        END
        ELSE
        BEGIN
            SET @lon_min = @lon_min - 1;
            SET @lon_max = @lon_max + 1;
        END
    END;
    
    -- Find intersections with longitude meridians
    DECLARE @lon INT = @lon_min;
    WHILE @lon <= @lon_max
    BEGIN
        INSERT INTO #Results (lat, lon, lat_label, lon_label)
        SELECT 
            ROUND(DEGREES(lat_rad), 9) as lat,
            lon,
            CASE WHEN DEGREES(lat_rad) >= 0 THEN CONCAT('N', FLOOR(DEGREES(lat_rad))) ELSE CONCAT('S', FLOOR(ABS(DEGREES(lat_rad)))) END as lat_label,
            CASE WHEN lon >= 0 THEN CONCAT('E', FLOOR(lon)) ELSE CONCAT('W', FLOOR(ABS(lon))) END as lon_label
        FROM dbo.IntersectWithLongitude(@lat1, @lon1, @lat2, @lon2, @lon)
        WHERE lat_rad IS NOT NULL;
        
        SET @lon = @lon + 1;
    END;
    
    -- Remove duplicates and sort results
    WITH Deduplicated AS (
        SELECT DISTINCT lat, lon, lat_label, lon_label
        FROM #Results
    )
    SELECT 
        lat,
        lon,
        lat_label,
        lon_label,
        CONCAT(lat, ', ', lon) as coordinates,
        CONCAT(lat_label, ', ', lon_label) as labels
    FROM Deduplicated
    ORDER BY lat, lon;
    
    DROP TABLE #Results;
END
GO

-- Helper procedure for pretty printing (optional)
CREATE OR ALTER PROCEDURE dbo.PrettyPrint_Intersections
    @lat1 FLOAT,
    @lon1 FLOAT,
    @lat2 FLOAT,
    @lon2 FLOAT,
    @npts INT = 200,
    @search_all_longitudes BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'GCT Intersections Results:';
    PRINT '========================';
    
    DECLARE @lat FLOAT, @lon FLOAT, @lat_label NVARCHAR(10), @lon_label NVARCHAR(10);
    DECLARE @coordinates NVARCHAR(50), @labels NVARCHAR(50);
    
    DECLARE result_cursor CURSOR FOR
    EXEC dbo.GCT_Intersections @lat1, @lon1, @lat2, @lon2, @npts, @search_all_longitudes;
    
    OPEN result_cursor;
    FETCH NEXT FROM result_cursor INTO @lat, @lon, @lat_label, @lon_label, @coordinates, @labels;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT @coordinates;
        PRINT @labels;
        PRINT '';
        
        FETCH NEXT FROM result_cursor INTO @lat, @lon, @lat_label, @lon_label, @coordinates, @labels;
    END;
    
    CLOSE result_cursor;
    DEALLOCATE result_cursor;
END
GO

-- Test the implementation with the provided example
EXEC dbo.PrettyPrint_Intersections 
    @lat1 = 21.2, 
    @lon1 = -60.1, 
    @lat2 = 18.7, 
    @lon2 = -58.4, 
    @npts = 400, 
    @search_all_longitudes = 1;