-- GCT Intersections - MS SQL Server 2019 Stored Procedure (Simplified Version)
-- Computes intersections of great-circle arc between two points with integer parallels and meridians
-- This version uses a more straightforward approach suitable for SQL Server

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

-- Helper function to calculate intermediate points on great circle
CREATE OR ALTER FUNCTION dbo.GetGreatCirclePoints(@lat1 FLOAT, @lon1 FLOAT, @lat2 FLOAT, @lon2 FLOAT, @npts INT)
RETURNS TABLE
AS
RETURN
(
    WITH Numbers AS (
        SELECT 0 as n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL
        SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL
        SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL
        SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL
        SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23 UNION ALL SELECT 24 UNION ALL
        SELECT 25 UNION ALL SELECT 26 UNION ALL SELECT 27 UNION ALL SELECT 28 UNION ALL SELECT 29 UNION ALL
        SELECT 30 UNION ALL SELECT 31 UNION ALL SELECT 32 UNION ALL SELECT 33 UNION ALL SELECT 34 UNION ALL
        SELECT 35 UNION ALL SELECT 36 UNION ALL SELECT 37 UNION ALL SELECT 38 UNION ALL SELECT 39 UNION ALL
        SELECT 40 UNION ALL SELECT 41 UNION ALL SELECT 42 UNION ALL SELECT 43 UNION ALL SELECT 44 UNION ALL
        SELECT 45 UNION ALL SELECT 46 UNION ALL SELECT 47 UNION ALL SELECT 48 UNION ALL SELECT 49 UNION ALL
        SELECT 50 UNION ALL SELECT 51 UNION ALL SELECT 52 UNION ALL SELECT 53 UNION ALL SELECT 54 UNION ALL
        SELECT 55 UNION ALL SELECT 56 UNION ALL SELECT 57 UNION ALL SELECT 58 UNION ALL SELECT 59 UNION ALL
        SELECT 60 UNION ALL SELECT 61 UNION ALL SELECT 62 UNION ALL SELECT 63 UNION ALL SELECT 64 UNION ALL
        SELECT 65 UNION ALL SELECT 66 UNION ALL SELECT 67 UNION ALL SELECT 68 UNION ALL SELECT 69 UNION ALL
        SELECT 70 UNION ALL SELECT 71 UNION ALL SELECT 72 UNION ALL SELECT 73 UNION ALL SELECT 74 UNION ALL
        SELECT 75 UNION ALL SELECT 76 UNION ALL SELECT 77 UNION ALL SELECT 78 UNION ALL SELECT 79 UNION ALL
        SELECT 80 UNION ALL SELECT 81 UNION ALL SELECT 82 UNION ALL SELECT 83 UNION ALL SELECT 84 UNION ALL
        SELECT 85 UNION ALL SELECT 86 UNION ALL SELECT 87 UNION ALL SELECT 88 UNION ALL SELECT 89 UNION ALL
        SELECT 90 UNION ALL SELECT 91 UNION ALL SELECT 92 UNION ALL SELECT 93 UNION ALL SELECT 94 UNION ALL
        SELECT 95 UNION ALL SELECT 96 UNION ALL SELECT 97 UNION ALL SELECT 98 UNION ALL SELECT 99 UNION ALL
        SELECT 100 UNION ALL SELECT 101 UNION ALL SELECT 102 UNION ALL SELECT 103 UNION ALL SELECT 104 UNION ALL
        SELECT 105 UNION ALL SELECT 106 UNION ALL SELECT 107 UNION ALL SELECT 108 UNION ALL SELECT 109 UNION ALL
        SELECT 110 UNION ALL SELECT 111 UNION ALL SELECT 112 UNION ALL SELECT 113 UNION ALL SELECT 114 UNION ALL
        SELECT 115 UNION ALL SELECT 116 UNION ALL SELECT 117 UNION ALL SELECT 118 UNION ALL SELECT 119 UNION ALL
        SELECT 120 UNION ALL SELECT 121 UNION ALL SELECT 122 UNION ALL SELECT 123 UNION ALL SELECT 124 UNION ALL
        SELECT 125 UNION ALL SELECT 126 UNION ALL SELECT 127 UNION ALL SELECT 128 UNION ALL SELECT 129 UNION ALL
        SELECT 130 UNION ALL SELECT 131 UNION ALL SELECT 132 UNION ALL SELECT 133 UNION ALL SELECT 134 UNION ALL
        SELECT 135 UNION ALL SELECT 136 UNION ALL SELECT 137 UNION ALL SELECT 138 UNION ALL SELECT 139 UNION ALL
        SELECT 140 UNION ALL SELECT 141 UNION ALL SELECT 142 UNION ALL SELECT 143 UNION ALL SELECT 144 UNION ALL
        SELECT 145 UNION ALL SELECT 146 UNION ALL SELECT 147 UNION ALL SELECT 148 UNION ALL SELECT 149 UNION ALL
        SELECT 150 UNION ALL SELECT 151 UNION ALL SELECT 152 UNION ALL SELECT 153 UNION ALL SELECT 154 UNION ALL
        SELECT 155 UNION ALL SELECT 156 UNION ALL SELECT 157 UNION ALL SELECT 158 UNION ALL SELECT 159 UNION ALL
        SELECT 160 UNION ALL SELECT 161 UNION ALL SELECT 162 UNION ALL SELECT 163 UNION ALL SELECT 164 UNION ALL
        SELECT 165 UNION ALL SELECT 166 UNION ALL SELECT 167 UNION ALL SELECT 168 UNION ALL SELECT 169 UNION ALL
        SELECT 170 UNION ALL SELECT 171 UNION ALL SELECT 172 UNION ALL SELECT 173 UNION ALL SELECT 174 UNION ALL
        SELECT 175 UNION ALL SELECT 176 UNION ALL SELECT 177 UNION ALL SELECT 178 UNION ALL SELECT 179 UNION ALL
        SELECT 180 UNION ALL SELECT 181 UNION ALL SELECT 182 UNION ALL SELECT 183 UNION ALL SELECT 184 UNION ALL
        SELECT 185 UNION ALL SELECT 186 UNION ALL SELECT 187 UNION ALL SELECT 188 UNION ALL SELECT 189 UNION ALL
        SELECT 190 UNION ALL SELECT 191 UNION ALL SELECT 192 UNION ALL SELECT 193 UNION ALL SELECT 194 UNION ALL
        SELECT 195 UNION ALL SELECT 196 UNION ALL SELECT 197 UNION ALL SELECT 198 UNION ALL SELECT 199 UNION ALL
        SELECT 200
    ),
    FilteredNumbers AS (
        SELECT n FROM Numbers WHERE n <= @npts
    ),
    Interpolated AS (
        SELECT 
            @lat1 + (@lat2 - @lat1) * (CAST(n AS FLOAT) / @npts) as lat,
            dbo.NormalizeLongitude(@lon1 + (@lon2 - @lon1) * (CAST(n AS FLOAT) / @npts)) as lon
        FROM FilteredNumbers
    )
    SELECT lat, lon FROM Interpolated
    UNION ALL
    SELECT @lat1 as lat, @lon1 as lon
    UNION ALL
    SELECT @lat2 as lat, @lon2 as lon
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
        lon_label NVARCHAR(10),
        coordinates NVARCHAR(50),
        labels NVARCHAR(50)
    );
    
    -- Get all points on the great circle
    INSERT INTO #Results (lat, lon, lat_label, lon_label, coordinates, labels)
    SELECT 
        ROUND(lat, 9) as lat,
        ROUND(lon, 9) as lon,
        CASE 
            WHEN lat >= 0 THEN CONCAT('N', FLOOR(lat))
            ELSE CONCAT('S', FLOOR(ABS(lat)))
        END as lat_label,
        CASE 
            WHEN lon >= 0 THEN CONCAT('E', FLOOR(lon))
            ELSE CONCAT('W', FLOOR(ABS(lon)))
        END as lon_label,
        CONCAT(ROUND(lat, 9), ', ', ROUND(lon, 9)) as coordinates,
        CONCAT(
            CASE WHEN lat >= 0 THEN CONCAT('N', FLOOR(lat)) ELSE CONCAT('S', FLOOR(ABS(lat))) END,
            ', ',
            CASE WHEN lon >= 0 THEN CONCAT('E', FLOOR(lon)) ELSE CONCAT('W', FLOOR(ABS(lon))) END
        ) as labels
    FROM dbo.GetGreatCirclePoints(@lat1, @lon1, @lat2, @lon2, @npts);
    
    -- Find intersections with integer latitude parallels
    DECLARE @lat_min INT = FLOOR(LEAST(@lat1, @lat2));
    DECLARE @lat_max INT = CEILING(GREATEST(@lat1, @lat2));
    
    -- Add intersections with latitude parallels
    WITH LatIntersections AS (
        SELECT DISTINCT
            CAST(lat_int AS FLOAT) as lat,
            ROUND(lon, 9) as lon,
            CASE 
                WHEN lat_int >= 0 THEN CONCAT('N', lat_int)
                ELSE CONCAT('S', ABS(lat_int))
            END as lat_label,
            CASE 
                WHEN lon >= 0 THEN CONCAT('E', FLOOR(lon))
                ELSE CONCAT('W', FLOOR(ABS(lon)))
            END as lon_label
        FROM (
            SELECT 
                FLOOR(lat) as lat_int,
                lon
            FROM dbo.GetGreatCirclePoints(@lat1, @lon1, @lat2, @lon2, @npts)
            WHERE FLOOR(lat) BETWEEN @lat_min AND @lat_max
            AND lat != FLOOR(lat) -- Exclude points that are already on integer latitudes
        ) intersections
    )
    INSERT INTO #Results (lat, lon, lat_label, lon_label, coordinates, labels)
    SELECT 
        lat, lon, lat_label, lon_label,
        CONCAT(lat, ', ', lon) as coordinates,
        CONCAT(lat_label, ', ', lon_label) as labels
    FROM LatIntersections;
    
    -- Find intersections with integer longitude meridians
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
    
    -- Add intersections with longitude meridians
    WITH LonIntersections AS (
        SELECT DISTINCT
            ROUND(lat, 9) as lat,
            CAST(lon_int AS FLOAT) as lon,
            CASE 
                WHEN lat >= 0 THEN CONCAT('N', FLOOR(lat))
                ELSE CONCAT('S', FLOOR(ABS(lat)))
            END as lat_label,
            CASE 
                WHEN lon_int >= 0 THEN CONCAT('E', lon_int)
                ELSE CONCAT('W', ABS(lon_int))
            END as lon_label
        FROM (
            SELECT 
                lat,
                FLOOR(lon) as lon_int
            FROM dbo.GetGreatCirclePoints(@lat1, @lon1, @lat2, @lon2, @npts)
            WHERE FLOOR(lon) BETWEEN @lon_min AND @lon_max
            AND lon != FLOOR(lon) -- Exclude points that are already on integer longitudes
        ) intersections
    )
    INSERT INTO #Results (lat, lon, lat_label, lon_label, coordinates, labels)
    SELECT 
        lat, lon, lat_label, lon_label,
        CONCAT(lat, ', ', lon) as coordinates,
        CONCAT(lat_label, ', ', lon_label) as labels
    FROM LonIntersections;
    
    -- Return results sorted by latitude then longitude
    SELECT DISTINCT
        lat,
        lon,
        lat_label,
        lon_label,
        coordinates,
        labels
    FROM #Results
    ORDER BY lat, lon;
    
    DROP TABLE #Results;
END
GO

-- Helper procedure for pretty printing
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
    PRINT '';
    
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
    
    PRINT 'Done tests.';
END
GO

-- Test the implementation with the provided example
PRINT 'Testing GCT Intersections with A=(21.2, -60.1), B=(18.7, -58.4)';
PRINT '================================================================';
EXEC dbo.PrettyPrint_Intersections 
    @lat1 = 21.2, 
    @lon1 = -60.1, 
    @lat2 = 18.7, 
    @lon2 = -58.4, 
    @npts = 400, 
    @search_all_longitudes = 1;