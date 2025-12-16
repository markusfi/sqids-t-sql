CREATE OR ALTER PROCEDURE sqids.RunEncodingTests
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================
       Test-Konstanten (fest, keine Parameter)
       ========================================================= */
    DECLARE @ConfigName SYSNAME       = N'default';
    DECLARE @Alphabet   NVARCHAR(255) = N'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    DECLARE @MinLength  INT           = 0;

    /* =========================================================
       Init (BlocklistJson = NULL => Default-Blocklist)
       Encode/Decode lesen intern aus sqids.Config
       ========================================================= */
    EXEC sqids.Init
        @ConfigName    = @ConfigName,
        @Alphabet      = @Alphabet,
        @MinLength     = @MinLength,
        @BlocklistJson = NULL;

    IF NOT EXISTS (SELECT 1 FROM sqids.Config WHERE ConfigName = @ConfigName)
        THROW 56001, 'Config row not found after Init.', 1;

    /* =========================================================
       Fail-Collector
       ========================================================= */
    CREATE TABLE #Fail
    (
        TestName NVARCHAR(140) NOT NULL,
        CaseName NVARCHAR(140) NULL,
        Input    NVARCHAR(MAX) NULL,
        Id       NVARCHAR(4000) NULL,
        Got      NVARCHAR(MAX) NULL,
        Expected NVARCHAR(MAX) NULL
    );

    /* Helper: JSON arrays compare by [key]+value (order sensitive like original arrays) */
    DECLARE @E NVARCHAR(MAX), @G NVARCHAR(MAX);

    /* =========================================================
       1) EncodeAndDecode_SingleNumber_ReturnsExactMatch (0..9)
       ========================================================= */
    DECLARE @single TABLE (n BIGINT NOT NULL, id NVARCHAR(50) NOT NULL);
    INSERT INTO @single(n,id) VALUES
        (0, N'bM'),
        (1, N'Uk'),
        (2, N'gb'),
        (3, N'Ef'),
        (4, N'Vq'),
        (5, N'uw'),
        (6, N'OI'),
        (7, N'AX'),
        (8, N'p6'),
        (9, N'nJ');

    DECLARE @n BIGINT, @idExp NVARCHAR(50), @idGot NVARCHAR(4000), @back BIGINT;

    DECLARE c1 CURSOR LOCAL FAST_FORWARD FOR
        SELECT n, id FROM @single ORDER BY n;
    OPEN c1;
    FETCH NEXT FROM c1 INTO @n, @idExp;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @idGot = sqids.ToId(@n);
        IF @idGot <> @idExp
            INSERT INTO #Fail(TestName, CaseName, Input, Id, Got, Expected)
            VALUES (N'EncodeAndDecode_SingleNumber_ReturnsExactMatch', CONVERT(NVARCHAR(40),@n),
                    CONVERT(NVARCHAR(40),@n), @idGot, @idGot, @idExp);

        SET @back = sqids.ToNumber(@idExp);
        IF @back <> @n
            INSERT INTO #Fail(TestName, CaseName, Input, Id, Got, Expected)
            VALUES (N'EncodeAndDecode_SingleNumber_ReturnsExactMatch', CONVERT(NVARCHAR(40),@n),
                    @idExp, @idExp, CONVERT(NVARCHAR(40),@back), CONVERT(NVARCHAR(40),@n));

        FETCH NEXT FROM c1 INTO @n, @idExp;
    END
    CLOSE c1; DEALLOCATE c1;

    /* =========================================================
       2) EncodeAndDecode_MultipleNumbers_ReturnsExactMatch
       ========================================================= */
    DECLARE @multiExact TABLE (CaseName NVARCHAR(140) NOT NULL, NumbersJson NVARCHAR(MAX) NOT NULL, IdExpected NVARCHAR(4000) NOT NULL);
    INSERT INTO @multiExact(CaseName, NumbersJson, IdExpected) VALUES
        (N'simple_[1,2,3]', N'[1,2,3]', N'86Rf07'),

        (N'inc_[0,0]', N'[0,0]', N'SvIz'),
        (N'inc_[0,1]', N'[0,1]', N'n3qa'),
        (N'inc_[0,2]', N'[0,2]', N'tryF'),
        (N'inc_[0,3]', N'[0,3]', N'eg6q'),
        (N'inc_[0,4]', N'[0,4]', N'rSCF'),
        (N'inc_[0,5]', N'[0,5]', N'sR8x'),
        (N'inc_[0,6]', N'[0,6]', N'uY2M'),
        (N'inc_[0,7]', N'[0,7]', N'74dI'),
        (N'inc_[0,8]', N'[0,8]', N'30WX'),
        (N'inc_[0,9]', N'[0,9]', N'moxr'),

        (N'inc_[1,0]', N'[1,0]', N'nWqP'),
        (N'inc_[2,0]', N'[2,0]', N'tSyw'),
        (N'inc_[3,0]', N'[3,0]', N'eX68'),
        (N'inc_[4,0]', N'[4,0]', N'rxCY'),
        (N'inc_[5,0]', N'[5,0]', N'sV8a'),
        (N'inc_[6,0]', N'[6,0]', N'uf2K'),
        (N'inc_[7,0]', N'[7,0]', N'7Cdk'),
        (N'inc_[8,0]', N'[8,0]', N'3aWP'),
        (N'inc_[9,0]', N'[9,0]', N'm2xn'),

        (N'empty_array', N'[]', N'');

    DECLARE @case NVARCHAR(140), @nums NVARCHAR(MAX);

    DECLARE c2 CURSOR LOCAL FAST_FORWARD FOR
        SELECT CaseName, NumbersJson, IdExpected FROM @multiExact ORDER BY CaseName;
    OPEN c2;
    FETCH NEXT FROM c2 INTO @case, @nums, @idExp;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @idGot = sqids.EncodeJson(@nums);
        IF ISNULL(@idGot,N'') <> @idExp
            INSERT INTO #Fail(TestName, CaseName, Input, Id, Got, Expected)
            VALUES (N'EncodeAndDecode_MultipleNumbers_ReturnsExactMatch.encode', @case, @nums, @idGot, @idGot, @idExp);

        SET @G = sqids.DecodeJson(@idExp);
        SET @E = @nums;

        IF EXISTS (SELECT [key], value FROM OPENJSON(@E) EXCEPT SELECT [key], value FROM OPENJSON(@G))
           OR EXISTS (SELECT [key], value FROM OPENJSON(@G) EXCEPT SELECT [key], value FROM OPENJSON(@E))
            INSERT INTO #Fail(TestName, CaseName, Input, Id, Got, Expected)
            VALUES (N'EncodeAndDecode_MultipleNumbers_ReturnsExactMatch.decode', @case, @nums, @idExp, @G, @E);

        FETCH NEXT FROM c2 INTO @case, @nums, @idExp;
    END
    CLOSE c2; DEALLOCATE c2;

    /* =========================================================
       3) EncodeAndDecode_MultipleNumbers_RoundTripsSuccessfully
       ========================================================= */
    DECLARE @roundTrips TABLE (CaseName NVARCHAR(140) NOT NULL, NumbersJson NVARCHAR(MAX) NOT NULL);
    INSERT INTO @roundTrips(CaseName, NumbersJson) VALUES
        (N'rt_mixed', N'[0,0,0,1,2,3,100,1000,100000,1000000,2147483647]'),
        (N'rt_0to99', N'['
            + N'0,1,2,3,4,5,6,7,8,9,'
            + N'10,11,12,13,14,15,16,17,18,19,'
            + N'20,21,22,23,24,25,26,27,28,29,'
            + N'30,31,32,33,34,35,36,37,38,39,'
            + N'40,41,42,43,44,45,46,47,48,49,'
            + N'50,51,52,53,54,55,56,57,58,59,'
            + N'60,61,62,63,64,65,66,67,68,69,'
            + N'70,71,72,73,74,75,76,77,78,79,'
            + N'80,81,82,83,84,85,86,87,88,89,'
            + N'90,91,92,93,94,95,96,97,98,99'
            + N']');

    DECLARE c3 CURSOR LOCAL FAST_FORWARD FOR
        SELECT CaseName, NumbersJson FROM @roundTrips ORDER BY CaseName;
    OPEN c3;
    FETCH NEXT FROM c3 INTO @case, @nums;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @idGot = sqids.EncodeJson(@nums);
        SET @G = sqids.DecodeJson(@idGot);
        SET @E = @nums;

        IF EXISTS (SELECT [key], value FROM OPENJSON(@E) EXCEPT SELECT [key], value FROM OPENJSON(@G))
           OR EXISTS (SELECT [key], value FROM OPENJSON(@G) EXCEPT SELECT [key], value FROM OPENJSON(@E))
            INSERT INTO #Fail(TestName, CaseName, Input, Id, Got, Expected)
            VALUES (N'EncodeAndDecode_MultipleNumbers_RoundTripsSuccessfully', @case, @nums, @idGot, @G, @E);

        FETCH NEXT FROM c3 INTO @case, @nums;
    END
    CLOSE c3; DEALLOCATE c3;

    /* =========================================================
       4) Decode_WithInvalidCharacters_ReturnsEmptyArray ("*")
       ========================================================= */
    SET @G = sqids.DecodeJson(N'*');
    IF @G <> N'[]'
        INSERT INTO #Fail(TestName, CaseName, Input, Got, Expected)
        VALUES (N'Decode_WithInvalidCharacters_ReturnsEmptyArray', N'*', N'*', @G, N'[]');

    /* =========================================================
       5) Encode_OutOfRangeNumber_Throws (in T-SQL: error OR NULL is acceptable)
       ========================================================= */
    BEGIN TRY
        SET @idGot = sqids.ToId(-1);
        IF @idGot IS NOT NULL
            INSERT INTO #Fail(TestName, CaseName, Input, Id, Got, Expected)
            VALUES (N'Encode_OutOfRangeNumber', N'-1', N'-1', @idGot, N'(not NULL)', N'ERROR or NULL');
    END TRY
    BEGIN CATCH
        -- ok: throwing is acceptable
        -- (optional) you could assert the error number/message here if you standardized it
    END CATCH;

    /* =========================================================
       6) SingleNumberOfDifferentIntegerTypes_RoundTripsSuccessfully (SQL analog)
       ========================================================= */
    DECLARE @singleTypes TABLE (CaseName NVARCHAR(60), n BIGINT);
    INSERT INTO @singleTypes(CaseName,n) VALUES
        (N'byte.MaxValue',   255),
        (N'sbyte.MaxValue',  127),
        (N'short.MaxValue',  32767),
        (N'ushort.MaxValue', 65535),
        (N'int.MaxValue',    2147483647),
        (N'uint.MaxValue',   4294967295),
        (N'long.MaxValue',   9223372036854775807);

    DECLARE c4 CURSOR LOCAL FAST_FORWARD FOR
        SELECT CaseName, n FROM @singleTypes ORDER BY CaseName;
    OPEN c4;
    FETCH NEXT FROM c4 INTO @case, @n;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @idGot = sqids.ToId(@n);
        SET @back = sqids.ToNumber(@idGot);

        IF @back <> @n
            INSERT INTO #Fail(TestName, CaseName, Input, Id, Got, Expected)
            VALUES (N'SingleNumberOfDifferentIntegerTypes_RoundTripsSuccessfully', @case,
                    CONVERT(NVARCHAR(40),@n), @idGot,
                    CONVERT(NVARCHAR(40),@back), CONVERT(NVARCHAR(40),@n));

        FETCH NEXT FROM c4 INTO @case, @n;
    END
    CLOSE c4; DEALLOCATE c4;

    /* =========================================================
       7) MultipleNumbersOfDifferentIntegerTypes_RoundTripsSuccessfully (SQL analog)
       (entspricht: [0, 1*part, 2*part, 3*part, 4*part, Max])
       ========================================================= */
    DECLARE @multiTypes TABLE (CaseName NVARCHAR(60), NumbersJson NVARCHAR(MAX));
    INSERT INTO @multiTypes(CaseName, NumbersJson) VALUES
        (N'byte',   N'[0,25,50,75,100,255]'),  -- 255/10 = 25
        (N'sbyte',  N'[0,12,24,36,48,127]'),   -- 127/10 = 12
        (N'short',  N'[0,3276,6552,9828,13104,32767]'),
        (N'ushort', N'[0,6553,13106,19659,26212,65535]'),
        (N'int',    N'[0,214748364,429496728,644245092,858993456,2147483647]'),
        (N'uint',   N'[0,429496729,858993458,1288490187,1717986916,4294967295]'),
        (N'long',   N'[0,922337203685477580,1844674407370955160,2767011611056432740,3689348814741910320,9223372036854775807]');

    DECLARE c5 CURSOR LOCAL FAST_FORWARD FOR
        SELECT CaseName, NumbersJson FROM @multiTypes ORDER BY CaseName;
    OPEN c5;
    FETCH NEXT FROM c5 INTO @case, @nums;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @idGot = sqids.EncodeJson(@nums);
        SET @G = sqids.DecodeJson(@idGot);
        SET @E = @nums;

        IF EXISTS (SELECT [key], value FROM OPENJSON(@E) EXCEPT SELECT [key], value FROM OPENJSON(@G))
           OR EXISTS (SELECT [key], value FROM OPENJSON(@G) EXCEPT SELECT [key], value FROM OPENJSON(@E))
            INSERT INTO #Fail(TestName, CaseName, Input, Id, Got, Expected)
            VALUES (N'MultipleNumbersOfDifferentIntegerTypes_RoundTripsSuccessfully', @case, @nums, @idGot, @G, @E);

        FETCH NEXT FROM c5 INTO @case, @nums;
    END
    CLOSE c5; DEALLOCATE c5;

    /* =========================================================
       Output
       ========================================================= */
    SELECT
        ConfigName = @ConfigName,
        Failures = (SELECT COUNT(*) FROM #Fail);

    SELECT *
    FROM #Fail
    ORDER BY TestName, CaseName;
END
GO

EXEC  sqids.RunEncodingTests
