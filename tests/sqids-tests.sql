CREATE OR ALTER PROCEDURE sqids.RunTests
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================
       Test-Konstanten (bei Bedarf hier ändern)
       ========================================================= */
    DECLARE @ConfigName SYSNAME       = N'default';
    DECLARE @Alphabet   NVARCHAR(255) = N'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    DECLARE @MinLength  INT           = 0;

    -- NULL => Init verwendet Default-Blocklist (deine Änderung)
    DECLARE @BlocklistJson NVARCHAR(MAX) = NULL;

    DECLARE @MaxN            INT = 10000;   -- Roundtrip 0..MaxN
    DECLARE @BlocklistSample INT = 100000;  -- Sample fürs Blocklist-Scanning

    /* =========================================================
       Constructor/Init-Validierungen (wie TS)
       ========================================================= */
    IF @Alphabet IS NULL OR LEN(@Alphabet) < 3
        THROW 55001, 'Alphabet length must be at least 3', 1;

    IF @MinLength < 0 OR @MinLength > 255
        THROW 55002, 'Minimum length has to be between 0 and 255', 1;

    -- ASCII only
    IF EXISTS (
        SELECT 1
        FROM master..spt_values v
        WHERE v.type='P'
          AND v.number BETWEEN 1 AND LEN(@Alphabet)
          AND UNICODE(SUBSTRING(@Alphabet, v.number, 1)) > 127
    )
        THROW 55003, 'Alphabet cannot contain multibyte characters', 1;

    -- Unique (case-sensitive)
    IF LEN(@Alphabet) <> (
        SELECT COUNT(DISTINCT SUBSTRING(@Alphabet, v.number, 1) COLLATE Latin1_General_100_BIN2)
        FROM master..spt_values v
        WHERE v.type='P' AND v.number BETWEEN 1 AND LEN(@Alphabet)
    )
        THROW 55004, 'Alphabet must contain unique characters', 1;

    /* =========================================================
       Init (Config wird befüllt; Encode/Decode lesen intern aus Config)
       ========================================================= */
    EXEC sqids.Init
        @ConfigName    = @ConfigName,
        @Alphabet      = @Alphabet,
        @MinLength     = @MinLength,
        @BlocklistJson = @BlocklistJson;

    -- Sanity: Config muss existieren und Blocklist muss (durch Default) gesetzt sein
    IF NOT EXISTS (SELECT 1 FROM sqids.Config WHERE ConfigName = @ConfigName)
        THROW 55005, 'Config row not found after Init.', 1;

    IF (SELECT BlocklistJson FROM sqids.Config WHERE ConfigName = @ConfigName) IS NULL
        THROW 55006, 'BlocklistJson is NULL after Init (expected default blocklist).', 1;

    /* =========================================================
       Fehler sammeln
       ========================================================= */
    CREATE TABLE #Fail
    (
        TestName NVARCHAR(100) NOT NULL,
        n INT NULL,
        id NVARCHAR(4000) NULL,
        got NVARCHAR(4000) NULL,
        expected NVARCHAR(4000) NULL
    );

    /* =========================================================
       1) Roundtrip Single: ToNumber(ToId(n)) = n
       ========================================================= */
    ;WITH nums AS (
        SELECT TOP (@MaxN + 1)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
        FROM sys.all_objects a
        CROSS JOIN sys.all_objects b
    ),
    rt AS (
        SELECT
            n,
            id   = sqids.ToId(n),
            back = sqids.ToNumber(sqids.ToId(n))
        FROM nums
    )
    INSERT INTO #Fail(TestName, n, id, got, expected)
    SELECT N'roundtrip_single', n, id, CONVERT(NVARCHAR(40), back), CONVERT(NVARCHAR(40), n)
    FROM rt
    WHERE id IS NULL OR back IS NULL OR back <> n;

    /* =========================================================
       2) MinLength muss eingehalten werden (wenn > 0)
       ========================================================= */
    IF EXISTS (SELECT 1 FROM sqids.Config WHERE ConfigName=@ConfigName AND MinLength > 0)
    BEGIN
        DECLARE @StoredMinLength INT = (SELECT MinLength FROM sqids.Config WHERE ConfigName=@ConfigName);

        ;WITH nums AS (
            SELECT TOP (5000)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        ),
        ids AS (
            SELECT n, id = sqids.ToId(n)
            FROM nums
        )
        INSERT INTO #Fail(TestName, n, id, got, expected)
        SELECT N'minLength', n, id,
               CONVERT(NVARCHAR(40), LEN(id)),
               CONVERT(NVARCHAR(40), @StoredMinLength)
        FROM ids
        WHERE id IS NULL OR LEN(id) < @StoredMinLength;
    END

    /* =========================================================
       3) Multi-number Roundtrip: DecodeJson(EncodeJson(nums)) = nums
       ========================================================= */
    DECLARE @cases TABLE (name NVARCHAR(60) NOT NULL, nums NVARCHAR(MAX) NOT NULL);
    INSERT INTO @cases(name, nums) VALUES
        (N'multi_[1,2,3]',              N'[1,2,3]'),
        (N'multi_[0,0,0]',              N'[0,0,0]'),
        (N'multi_[10,100,1000,1108]',   N'[10,100,1000,1108]'),
        (N'multi_[999,1,999,2]',        N'[999,1,999,2]'),
        (N'multi_[0,1,0,1,0,1]',        N'[0,1,0,1,0,1]');

    DECLARE @caseName NVARCHAR(60), @numsJson NVARCHAR(MAX);
    DECLARE @id NVARCHAR(4000), @dec NVARCHAR(MAX);

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT name, nums FROM @cases ORDER BY name;

    OPEN c;
    FETCH NEXT FROM c INTO @caseName, @numsJson;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @id  = sqids.EncodeJson(@numsJson);
        SET @dec = sqids.DecodeJson(@id);

        IF @id IS NULL
            INSERT INTO #Fail(TestName, id, got, expected)
            VALUES (@caseName, NULL, N'EncodeJson returned NULL', @numsJson);
        ELSE IF @dec <> @numsJson
            INSERT INTO #Fail(TestName, id, got, expected)
            VALUES (@caseName, @id, @dec, @numsJson);

        FETCH NEXT FROM c INTO @caseName, @numsJson;
    END

    CLOSE c; DEALLOCATE c;

    /* =========================================================
       4) Decode: ungültiges Zeichen => []
       ========================================================= */
    DECLARE @invalid NVARCHAR(50) = N'abc-def';
    DECLARE @decodedInvalid NVARCHAR(MAX) = sqids.DecodeJson(@invalid);

    IF @decodedInvalid <> N'[]'
        INSERT INTO #Fail(TestName, id, got, expected)
        VALUES (N'decode_invalid_char', @invalid, @decodedInvalid, N'[]');

    /* =========================================================
       5) Blocklist: erzeugte IDs dürfen nicht blocked sein
          (Init setzt immer Blocklist, auch Default)
       ========================================================= */
    IF OBJECT_ID('sqids._IsBlocked', 'FN') IS NOT NULL
    BEGIN
        ;WITH nums AS (
            SELECT TOP (@BlocklistSample + 1)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        ),
        ids AS (
            SELECT n, id = sqids.ToId(n)
            FROM nums
        )
        INSERT INTO #Fail(TestName, n, id, got, expected)
        SELECT TOP (200)
               N'blocklist_hit',
               n,
               id,
               N'blocked',
               N'not blocked'
        FROM ids
        WHERE id IS NOT NULL
          AND sqids._IsBlocked(id, @alphabet, @blocklistJson) = 1
        ORDER BY n;
    END
    ELSE
    BEGIN
        INSERT INTO #Fail(TestName, got, expected)
        VALUES (N'blocklist_hit', N'skipped (sqids._IsBlocked not found)', N'function exists');
    END

    /* =========================================================
       Ergebnis
       ========================================================= */
    SELECT
        ConfigName = @ConfigName,
        MinLengthStored = (SELECT MinLength FROM sqids.Config WHERE ConfigName=@ConfigName),
        Failures = (SELECT COUNT(*) FROM #Fail);

    SELECT * FROM #Fail ORDER BY TestName, n;
END
GO


EXEC sqids.RunTests;