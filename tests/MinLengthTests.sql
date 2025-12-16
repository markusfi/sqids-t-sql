CREATE OR ALTER PROCEDURE sqids.RunMinLengthTests
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ConfigName SYSNAME       = N'default';
    DECLARE @Alphabet   NVARCHAR(255) = N'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    DECLARE @MinLength  INT           = len(@Alphabet);

    CREATE TABLE #Fail
    (
        TestName  NVARCHAR(120) NOT NULL,
        MinLength INT           NULL,
        Id        NVARCHAR(4000) NULL,
        Got       NVARCHAR(MAX) NULL,
        Expected  NVARCHAR(MAX) NULL
    );

    /* Helper: compare two JSON arrays by index+value (no whitespace sensitivity) */
    DECLARE @E NVARCHAR(MAX), @G NVARCHAR(MAX);

    /* =========================================================
       testSimple()
       ========================================================= */
    EXEC sqids.Init @ConfigName=@ConfigName, @Alphabet=@Alphabet, @MinLength=@MinLength, @BlocklistJson=NULL;

    DECLARE @numbersSimple NVARCHAR(MAX) = N'[1,2,3]';
    DECLARE @idSimpleExpected NVARCHAR(4000) =
        N'86Rf07xd4zBmiJXQG6otHEbew02c3PWsUOLZxADhCpKj7aVFv9I8RquYrNlSTM';

    DECLARE @idSimpleGot NVARCHAR(4000) = sqids.EncodeJson(@numbersSimple);
    IF @idSimpleGot <> @idSimpleExpected
        INSERT INTO #Fail(TestName, MinLength, Id, Got, Expected)
        VALUES (N'testSimple.encode', @MinLength, @idSimpleGot, @idSimpleGot, @idSimpleExpected);

    SET @G = sqids.DecodeJson(@idSimpleExpected);
    SET @E = @numbersSimple;

    IF EXISTS (
        SELECT [key], value FROM OPENJSON(@E)
        EXCEPT
        SELECT [key], value FROM OPENJSON(@G)
    ) OR EXISTS (
        SELECT [key], value FROM OPENJSON(@G)
        EXCEPT
        SELECT [key], value FROM OPENJSON(@E)
    )
        INSERT INTO #Fail(TestName, MinLength, Id, Got, Expected)
        VALUES (N'testSimple.decode', LEN(@Alphabet), @idSimpleExpected, @G, @E);

    /* =========================================================
       testIncremental()
       ========================================================= */
    DECLARE @inc TABLE (MinLength INT NOT NULL, ExpectedId NVARCHAR(4000) NOT NULL);
    INSERT INTO @inc(MinLength, ExpectedId) VALUES
        (6,  N'86Rf07'),
        (7,  N'86Rf07x'),
        (8,  N'86Rf07xd'),
        (9,  N'86Rf07xd4'),
        (10, N'86Rf07xd4z'),
        (11, N'86Rf07xd4zB'),
        (12, N'86Rf07xd4zBm'),
        (13, N'86Rf07xd4zBmi'),
        (LEN(@Alphabet) + 0, N'86Rf07xd4zBmiJXQG6otHEbew02c3PWsUOLZxADhCpKj7aVFv9I8RquYrNlSTM'),
        (LEN(@Alphabet) + 1, N'86Rf07xd4zBmiJXQG6otHEbew02c3PWsUOLZxADhCpKj7aVFv9I8RquYrNlSTMy'),
        (LEN(@Alphabet) + 2, N'86Rf07xd4zBmiJXQG6otHEbew02c3PWsUOLZxADhCpKj7aVFv9I8RquYrNlSTMyf'),
        (LEN(@Alphabet) + 3, N'86Rf07xd4zBmiJXQG6otHEbew02c3PWsUOLZxADhCpKj7aVFv9I8RquYrNlSTMyf1');

    DECLARE @ml INT, @idExp NVARCHAR(4000);
    DECLARE inc CURSOR LOCAL FAST_FORWARD FOR
        SELECT MinLength, ExpectedId FROM @inc ORDER BY MinLength;

    OPEN inc;
    FETCH NEXT FROM inc INTO @ml, @idExp;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sqids.Init @ConfigName=@ConfigName, @Alphabet=@Alphabet, @MinLength=@ml, @BlocklistJson=NULL;

        DECLARE @idGot NVARCHAR(4000) = sqids.EncodeJson(@numbersSimple);
        IF @idGot <> @idExp
            INSERT INTO #Fail(TestName, MinLength, Id, Got, Expected)
            VALUES (N'testIncremental.encode', @ml, @idGot, @idGot, @idExp);

        IF LEN(@idGot) <> @ml
            INSERT INTO #Fail(TestName, MinLength, Id, Got, Expected)
            VALUES (N'testIncremental.length', @ml, @idGot, CONVERT(NVARCHAR(40), LEN(@idGot)), CONVERT(NVARCHAR(40), @ml));

        SET @G = sqids.DecodeJson(@idExp);
        SET @E = @numbersSimple;

        IF EXISTS (
            SELECT [key], value FROM OPENJSON(@E)
            EXCEPT
            SELECT [key], value FROM OPENJSON(@G)
        ) OR EXISTS (
            SELECT [key], value FROM OPENJSON(@G)
            EXCEPT
            SELECT [key], value FROM OPENJSON(@E)
        )
            INSERT INTO #Fail(TestName, MinLength, Id, Got, Expected)
            VALUES (N'testIncremental.decode', @ml, @idExp, @G, @E);

        FETCH NEXT FROM inc INTO @ml, @idExp;
    END

    CLOSE inc;
    DEALLOCATE inc;

    /* =========================================================
       testIncrementalNumbers()
       ========================================================= */
    EXEC sqids.Init @ConfigName=@ConfigName, @Alphabet=@Alphabet, @MinLength=@MinLength, @BlocklistJson=NULL;

    DECLARE @pairs TABLE (ExpectedId NVARCHAR(4000) NOT NULL, NumbersJson NVARCHAR(MAX) NOT NULL);
    INSERT INTO @pairs(ExpectedId, NumbersJson) VALUES
        (N'SvIzsqYMyQwI3GWgJAe17URxX8V924Co0DaTZLtFjHriEn5bPhcSkfmvOslpBu', N'[0,0]'),
        (N'n3qafPOLKdfHpuNw3M61r95svbeJGk7aAEgYn4WlSjXURmF8IDqZBy0CT2VxQc', N'[0,1]'),
        (N'tryFJbWcFMiYPg8sASm51uIV93GXTnvRzyfLleh06CpodJD42B7OraKtkQNxUZ', N'[0,2]'),
        (N'eg6ql0A3XmvPoCzMlB6DraNGcWSIy5VR8iYup2Qk4tjZFKe1hbwfgHdUTsnLqE', N'[0,3]'),
        (N'rSCFlp0rB2inEljaRdxKt7FkIbODSf8wYgTsZM1HL9JzN35cyoqueUvVWCm4hX', N'[0,4]'),
        (N'sR8xjC8WQkOwo74PnglH1YFdTI0eaf56RGVSitzbjuZ3shNUXBrqLxEJyAmKv2', N'[0,5]'),
        (N'uY2MYFqCLpgx5XQcjdtZK286AwWV7IBGEfuS9yTmbJvkzoUPeYRHr4iDs3naN0', N'[0,6]'),
        (N'74dID7X28VLQhBlnGmjZrec5wTA1fqpWtK4YkaoEIM9SRNiC3gUJH0OFvsPDdy', N'[0,7]'),
        (N'30WXpesPhgKiEI5RHTY7xbB1GnytJvXOl2p0AcUjdF6waZDo9Qk8VLzMuWrqCS', N'[0,8]'),
        (N'moxr3HqLAK0GsTND6jowfZz3SUx7cQ8aC54Pl1RbIvFXmEJuBMYVeW9yrdOtin', N'[0,9]');

    DECLARE @pid NVARCHAR(4000), @pnums NVARCHAR(MAX);
    DECLARE pcur CURSOR LOCAL FAST_FORWARD FOR
        SELECT ExpectedId, NumbersJson FROM @pairs ORDER BY ExpectedId;

    OPEN pcur;
    FETCH NEXT FROM pcur INTO @pid, @pnums;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @idGot = sqids.EncodeJson(@pnums);
        IF @idGot <> @pid
            INSERT INTO #Fail(TestName, MinLength, Id, Got, Expected)
            VALUES (N'testIncrementalNumbers.encode', LEN(@Alphabet), @idGot, @idGot, @pid);

        SET @G = sqids.DecodeJson(@pid);
        SET @E = @pnums;

        IF EXISTS (
            SELECT [key], value FROM OPENJSON(@E)
            EXCEPT
            SELECT [key], value FROM OPENJSON(@G)
        ) OR EXISTS (
            SELECT [key], value FROM OPENJSON(@G)
            EXCEPT
            SELECT [key], value FROM OPENJSON(@E)
        )
            INSERT INTO #Fail(TestName, MinLength, Id, Got, Expected)
            VALUES (N'testIncrementalNumbers.decode', LEN(@Alphabet), @pid, @G, @E);

        FETCH NEXT FROM pcur INTO @pid, @pnums;
    END

    CLOSE pcur;
    DEALLOCATE pcur;

    /* =========================================================
       testMinLengths()
       ========================================================= */
    DECLARE @minLens TABLE (MinLength INT NOT NULL);
    INSERT INTO @minLens(MinLength) VALUES (0),(1),(5),(10),(LEN(@Alphabet));

    DECLARE @numSets TABLE (NumbersJson NVARCHAR(MAX) NOT NULL);
    INSERT INTO @numSets(NumbersJson) VALUES
        (N'[0]'),
        (N'[0,0,0,0,0]'),
        (N'[1,2,3,4,5,6,7,8,9,10]'),
        (N'[100,200,300]'),
        (N'[1000,2000,3000]'),
        (N'[1000000]'),
        (N'[9223372036854775807]'); -- Sqids.Id.max (Int64.max)

    DECLARE @m INT, @nums NVARCHAR(MAX);
    DECLARE mcur CURSOR LOCAL FAST_FORWARD FOR SELECT MinLength FROM @minLens ORDER BY MinLength;
    OPEN mcur;
    FETCH NEXT FROM mcur INTO @m;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sqids.Init @ConfigName=@ConfigName, @Alphabet=@Alphabet, @MinLength=@m, @BlocklistJson=NULL;

        DECLARE ncur CURSOR LOCAL FAST_FORWARD FOR SELECT NumbersJson FROM @numSets;
        OPEN ncur;
        FETCH NEXT FROM ncur INTO @nums;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @idGot = sqids.EncodeJson(@nums);

            IF @idGot IS NULL
                INSERT INTO #Fail(TestName, MinLength, Got, Expected)
                VALUES (N'testMinLengths.encode_NULL', @m, N'EncodeJson returned NULL', @nums);
            ELSE
            BEGIN
                IF LEN(@idGot) < @m
                    INSERT INTO #Fail(TestName, MinLength, Id, Got, Expected)
                    VALUES (N'testMinLengths.length', @m, @idGot, CONVERT(NVARCHAR(40), LEN(@idGot)), CONVERT(NVARCHAR(40), @m));

                SET @G = sqids.DecodeJson(@idGot);
                SET @E = @nums;

                IF EXISTS (
                    SELECT [key], value FROM OPENJSON(@E)
                    EXCEPT
                    SELECT [key], value FROM OPENJSON(@G)
                ) OR EXISTS (
                    SELECT [key], value FROM OPENJSON(@G)
                    EXCEPT
                    SELECT [key], value FROM OPENJSON(@E)
                )
                    INSERT INTO #Fail(TestName, MinLength, Id, Got, Expected)
                    VALUES (N'testMinLengths.decode', @m, @idGot, @G, @E);
            END

            FETCH NEXT FROM ncur INTO @nums;
        END

        CLOSE ncur;
        DEALLOCATE ncur;

        FETCH NEXT FROM mcur INTO @m;
    END

    CLOSE mcur;
    DEALLOCATE mcur;

    /* =========================================================
       Output
       ========================================================= */
    SELECT
        ConfigName = @ConfigName,
        Alphabet = @Alphabet,
        Failures = (SELECT COUNT(*) FROM #Fail);

    SELECT *
    FROM #Fail
    ORDER BY TestName, MinLength, Id;
END
GO

EXEC sqids.RunMinLengthTests;
