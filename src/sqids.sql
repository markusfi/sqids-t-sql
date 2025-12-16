/* =======================
   Cleanup
   ======================= */
DROP FUNCTION IF EXISTS sqids.ToId;
DROP FUNCTION IF EXISTS sqids.ToNumber;
DROP FUNCTION IF EXISTS sqids.EncodeJson;
DROP FUNCTION IF EXISTS sqids.DecodeJson;
DROP FUNCTION IF EXISTS sqids._Shuffle;
DROP FUNCTION IF EXISTS sqids._SplitReverse;
DROP FUNCTION IF EXISTS sqids._ToIdBase;
DROP FUNCTION IF EXISTS sqids._ToNumberBase;
DROP FUNCTION IF EXISTS sqids._IsBlocked;
DROP FUNCTION IF EXISTS sqids._FilterBlocklistJson;
DROP FUNCTION IF EXISTS sqids._ToNumberBase;
DROP FUNCTION IF EXISTS sqids._IndexOfChar;
drop function IF EXISTS sqids._ConsistentShuffle;
drop function IF EXISTS sqids._ToNumBase;
drop procedure IF EXISTS sqids.init;
drop procedure IF EXISTS sqids.RunTests;
drop procedure IF EXISTS sqids.RunMinLengthTests;
drop procedure IF EXISTS sqids.RunEncodingTests;
drop table IF EXISTS sqids.Config;
drop schema sqids;
drop schema IF EXISTS sqids;
GO

IF SCHEMA_ID('sqids') IS NULL EXEC('CREATE SCHEMA sqids');
GO

IF OBJECT_ID('sqids.Config', 'U') IS NULL
BEGIN
    CREATE TABLE sqids.Config
    (
        ConfigName       SYSNAME       NOT NULL PRIMARY KEY,
        Alphabet		 NVARCHAR(255)  NOT NULL,
        MinLength        INT           NOT NULL CONSTRAINT DF_SqidsConfig_MinLength DEFAULT(0),
        BlocklistJson    NVARCHAR(MAX)  NULL,
        UpdatedAt        DATETIME2(0)   NOT NULL CONSTRAINT DF_SqidsConfig_UpdatedAt DEFAULT(SYSDATETIME())
    );
END
GO

CREATE OR ALTER PROCEDURE sqids.Init
(
    @ConfigName  SYSNAME,
    @Alphabet    NVARCHAR(255),
    @MinLength   INT = 0,
    @BlocklistJson NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @ConfigName IS NULL OR LTRIM(RTRIM(@ConfigName)) = N''
        THROW 50000, 'ConfigName required.', 1;

    IF @Alphabet IS NULL OR LEN(@Alphabet) < 3
        THROW 50001, 'Alphabet length must be at least 3.', 1;

    IF @MinLength < 0 OR @MinLength > 255
        THROW 50002, 'MinLength must be between 0 and 255.', 1;

    -- ASCII only (wie Swift assert isASCII)
    IF EXISTS (
        SELECT 1
        WHERE EXISTS (
            SELECT 1
            FROM (SELECT TOP (LEN(@Alphabet)) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
                  FROM sys.all_objects) t
            WHERE UNICODE(SUBSTRING(@Alphabet, t.n, 1)) > 127
        )
    )
        THROW 50003, 'Alphabet cannot contain multibyte characters.', 1;

    DECLARE @len INT = LEN(@Alphabet);

    if @BlocklistJson is null
    set @BlocklistJson = '[
    "0rgasm",
    "1d10t",
    "1d1ot",
    "1di0t",
    "1diot",
    "1eccacu10",
    "1eccacu1o",
    "1eccacul0",
    "1eccaculo",
    "1mbec11e",
    "1mbec1le",
    "1mbeci1e",
    "1mbecile",
    "a11upat0",
    "a11upato",
    "a1lupat0",
    "a1lupato",
    "aand",
    "ah01e",
    "ah0le",
    "aho1e",
    "ahole",
    "al1upat0",
    "al1upato",
    "allupat0",
    "allupato",
    "ana1",
    "ana1e",
    "anal",
    "anale",
    "anus",
    "arrapat0",
    "arrapato",
    "arsch",
    "arse",
    "ass",
    "b00b",
    "b00be",
    "b01ata",
    "b0ceta",
    "b0iata",
    "b0ob",
    "b0obe",
    "b0sta",
    "b1tch",
    "b1te",
    "b1tte",
    "ba1atkar",
    "balatkar",
    "bastard0",
    "bastardo",
    "batt0na",
    "battona",
    "bitch",
    "bite",
    "bitte",
    "bo0b",
    "bo0be",
    "bo1ata",
    "boceta",
    "boiata",
    "boob",
    "boobe",
    "bosta",
    "bran1age",
    "bran1er",
    "bran1ette",
    "bran1eur",
    "bran1euse",
    "branlage",
    "branler",
    "branlette",
    "branleur",
    "branleuse",
    "c0ck",
    "c0g110ne",
    "c0g11one",
    "c0g1i0ne",
    "c0g1ione",
    "c0gl10ne",
    "c0gl1one",
    "c0gli0ne",
    "c0glione",
    "c0na",
    "c0nnard",
    "c0nnasse",
    "c0nne",
    "c0u111es",
    "c0u11les",
    "c0u1l1es",
    "c0u1lles",
    "c0ui11es",
    "c0ui1les",
    "c0uil1es",
    "c0uilles",
    "c11t",
    "c11t0",
    "c11to",
    "c1it",
    "c1it0",
    "c1ito",
    "cabr0n",
    "cabra0",
    "cabrao",
    "cabron",
    "caca",
    "cacca",
    "cacete",
    "cagante",
    "cagar",
    "cagare",
    "cagna",
    "cara1h0",
    "cara1ho",
    "caracu10",
    "caracu1o",
    "caracul0",
    "caraculo",
    "caralh0",
    "caralho",
    "cazz0",
    "cazz1mma",
    "cazzata",
    "cazzimma",
    "cazzo",
    "ch00t1a",
    "ch00t1ya",
    "ch00tia",
    "ch00tiya",
    "ch0d",
    "ch0ot1a",
    "ch0ot1ya",
    "ch0otia",
    "ch0otiya",
    "ch1asse",
    "ch1avata",
    "ch1er",
    "ch1ng0",
    "ch1ngadaz0s",
    "ch1ngadazos",
    "ch1ngader1ta",
    "ch1ngaderita",
    "ch1ngar",
    "ch1ngo",
    "ch1ngues",
    "ch1nk",
    "chatte",
    "chiasse",
    "chiavata",
    "chier",
    "ching0",
    "chingadaz0s",
    "chingadazos",
    "chingader1ta",
    "chingaderita",
    "chingar",
    "chingo",
    "chingues",
    "chink",
    "cho0t1a",
    "cho0t1ya",
    "cho0tia",
    "cho0tiya",
    "chod",
    "choot1a",
    "choot1ya",
    "chootia",
    "chootiya",
    "cl1t",
    "cl1t0",
    "cl1to",
    "clit",
    "clit0",
    "clito",
    "cock",
    "cog110ne",
    "cog11one",
    "cog1i0ne",
    "cog1ione",
    "cogl10ne",
    "cogl1one",
    "cogli0ne",
    "coglione",
    "cona",
    "connard",
    "connasse",
    "conne",
    "cou111es",
    "cou11les",
    "cou1l1es",
    "cou1lles",
    "coui11es",
    "coui1les",
    "couil1es",
    "couilles",
    "cracker",
    "crap",
    "cu10",
    "cu1att0ne",
    "cu1attone",
    "cu1er0",
    "cu1ero",
    "cu1o",
    "cul0",
    "culatt0ne",
    "culattone",
    "culer0",
    "culero",
    "culo",
    "cum",
    "cunt",
    "d11d0",
    "d11do",
    "d1ck",
    "d1ld0",
    "d1ldo",
    "damn",
    "de1ch",
    "deich",
    "depp",
    "di1d0",
    "di1do",
    "dick",
    "dild0",
    "dildo",
    "dyke",
    "encu1e",
    "encule",
    "enema",
    "enf01re",
    "enf0ire",
    "enfo1re",
    "enfoire",
    "estup1d0",
    "estup1do",
    "estupid0",
    "estupido",
    "etr0n",
    "etron",
    "f0da",
    "f0der",
    "f0ttere",
    "f0tters1",
    "f0ttersi",
    "f0tze",
    "f0utre",
    "f1ca",
    "f1cker",
    "f1ga",
    "fag",
    "fica",
    "ficker",
    "figa",
    "foda",
    "foder",
    "fottere",
    "fotters1",
    "fottersi",
    "fotze",
    "foutre",
    "fr0c10",
    "fr0c1o",
    "fr0ci0",
    "fr0cio",
    "fr0sc10",
    "fr0sc1o",
    "fr0sci0",
    "fr0scio",
    "froc10",
    "froc1o",
    "froci0",
    "frocio",
    "frosc10",
    "frosc1o",
    "frosci0",
    "froscio",
    "fuck",
    "g00",
    "g0o",
    "g0u1ne",
    "g0uine",
    "gandu",
    "go0",
    "goo",
    "gou1ne",
    "gouine",
    "gr0gnasse",
    "grognasse",
    "haram1",
    "harami",
    "haramzade",
    "hund1n",
    "hundin",
    "id10t",
    "id1ot",
    "idi0t",
    "idiot",
    "imbec11e",
    "imbec1le",
    "imbeci1e",
    "imbecile",
    "j1zz",
    "jerk",
    "jizz",
    "k1ke",
    "kam1ne",
    "kamine",
    "kike",
    "leccacu10",
    "leccacu1o",
    "leccacul0",
    "leccaculo",
    "m1erda",
    "m1gn0tta",
    "m1gnotta",
    "m1nch1a",
    "m1nchia",
    "m1st",
    "mam0n",
    "mamahuev0",
    "mamahuevo",
    "mamon",
    "masturbat10n",
    "masturbat1on",
    "masturbate",
    "masturbati0n",
    "masturbation",
    "merd0s0",
    "merd0so",
    "merda",
    "merde",
    "merdos0",
    "merdoso",
    "mierda",
    "mign0tta",
    "mignotta",
    "minch1a",
    "minchia",
    "mist",
    "musch1",
    "muschi",
    "n1gger",
    "neger",
    "negr0",
    "negre",
    "negro",
    "nerch1a",
    "nerchia",
    "nigger",
    "orgasm",
    "p00p",
    "p011a",
    "p01la",
    "p0l1a",
    "p0lla",
    "p0mp1n0",
    "p0mp1no",
    "p0mpin0",
    "p0mpino",
    "p0op",
    "p0rca",
    "p0rn",
    "p0rra",
    "p0uff1asse",
    "p0uffiasse",
    "p1p1",
    "p1pi",
    "p1r1a",
    "p1rla",
    "p1sc10",
    "p1sc1o",
    "p1sci0",
    "p1scio",
    "p1sser",
    "pa11e",
    "pa1le",
    "pal1e",
    "palle",
    "pane1e1r0",
    "pane1e1ro",
    "pane1eir0",
    "pane1eiro",
    "panele1r0",
    "panele1ro",
    "paneleir0",
    "paneleiro",
    "patakha",
    "pec0r1na",
    "pec0rina",
    "pecor1na",
    "pecorina",
    "pen1s",
    "pendej0",
    "pendejo",
    "penis",
    "pip1",
    "pipi",
    "pir1a",
    "pirla",
    "pisc10",
    "pisc1o",
    "pisci0",
    "piscio",
    "pisser",
    "po0p",
    "po11a",
    "po1la",
    "pol1a",
    "polla",
    "pomp1n0",
    "pomp1no",
    "pompin0",
    "pompino",
    "poop",
    "porca",
    "porn",
    "porra",
    "pouff1asse",
    "pouffiasse",
    "pr1ck",
    "prick",
    "pussy",
    "put1za",
    "puta",
    "puta1n",
    "putain",
    "pute",
    "putiza",
    "puttana",
    "queca",
    "r0mp1ba11e",
    "r0mp1ba1le",
    "r0mp1bal1e",
    "r0mp1balle",
    "r0mpiba11e",
    "r0mpiba1le",
    "r0mpibal1e",
    "r0mpiballe",
    "rand1",
    "randi",
    "rape",
    "recch10ne",
    "recch1one",
    "recchi0ne",
    "recchione",
    "retard",
    "romp1ba11e",
    "romp1ba1le",
    "romp1bal1e",
    "romp1balle",
    "rompiba11e",
    "rompiba1le",
    "rompibal1e",
    "rompiballe",
    "ruff1an0",
    "ruff1ano",
    "ruffian0",
    "ruffiano",
    "s1ut",
    "sa10pe",
    "sa1aud",
    "sa1ope",
    "sacanagem",
    "sal0pe",
    "salaud",
    "salope",
    "saugnapf",
    "sb0rr0ne",
    "sb0rra",
    "sb0rrone",
    "sbattere",
    "sbatters1",
    "sbattersi",
    "sborr0ne",
    "sborra",
    "sborrone",
    "sc0pare",
    "sc0pata",
    "sch1ampe",
    "sche1se",
    "sche1sse",
    "scheise",
    "scheisse",
    "schlampe",
    "schwachs1nn1g",
    "schwachs1nnig",
    "schwachsinn1g",
    "schwachsinnig",
    "schwanz",
    "scopare",
    "scopata",
    "sexy",
    "sh1t",
    "shit",
    "slut",
    "sp0mp1nare",
    "sp0mpinare",
    "spomp1nare",
    "spompinare",
    "str0nz0",
    "str0nza",
    "str0nzo",
    "stronz0",
    "stronza",
    "stronzo",
    "stup1d",
    "stupid",
    "succh1am1",
    "succh1ami",
    "succhiam1",
    "succhiami",
    "sucker",
    "t0pa",
    "tapette",
    "test1c1e",
    "test1cle",
    "testic1e",
    "testicle",
    "tette",
    "topa",
    "tr01a",
    "tr0ia",
    "tr0mbare",
    "tr1ng1er",
    "tr1ngler",
    "tring1er",
    "tringler",
    "tro1a",
    "troia",
    "trombare",
    "turd",
    "twat",
    "vaffancu10",
    "vaffancu1o",
    "vaffancul0",
    "vaffanculo",
    "vag1na",
    "vagina",
    "verdammt",
    "verga",
    "w1chsen",
    "wank",
    "wichsen",
    "x0ch0ta",
    "x0chota",
    "xana",
    "xoch0ta",
    "xochota",
    "z0cc01a",
    "z0cc0la",
    "z0cco1a",
    "z0ccola",
    "z1z1",
    "z1zi",
    "ziz1",
    "zizi",
    "zocc01a",
    "zocc0la",
    "zocco1a",
    "zoccola",
]';

    
    IF @len <> (
        SELECT COUNT(DISTINCT SUBSTRING(@Alphabet, v.number, 1) COLLATE Latin1_General_100_BIN2)
        FROM master..spt_values v
        WHERE v.type = 'P' AND v.number BETWEEN 1 AND @len
    )
        THROW 50004, 'Alphabet must contain unique characters.', 1;

    MERGE sqids.Config AS tgt
    USING (SELECT @ConfigName AS ConfigName) AS src
    ON tgt.ConfigName = src.ConfigName
    WHEN MATCHED THEN UPDATE SET
        Alphabet = @Alphabet,
        MinLength        = @MinLength,
        BlocklistJson    = @BlocklistJson,
        UpdatedAt        = SYSDATETIME()
    WHEN NOT MATCHED THEN INSERT (ConfigName, Alphabet, MinLength, BlocklistJson)
        VALUES (@ConfigName, @Alphabet, @MinLength, @BlocklistJson);
END
GO

CREATE OR ALTER FUNCTION sqids._IndexOfChar
(
    @alphabet NVARCHAR(255),
    @ch NCHAR(1)
)
RETURNS INT
AS
BEGIN
    DECLARE @target INT = UNICODE(@ch);
    DECLARE @i INT = 1;
    DECLARE @L INT = LEN(@alphabet);

    WHILE @i <= @L
    BEGIN
        IF UNICODE(SUBSTRING(@alphabet, @i, 1)) = @target
            RETURN @i - 1; -- 0-based like Swift
        SET @i += 1;
    END

    RETURN -1;
END
GO



/* =======================
   shuffle(alphabet: [Character]) -> [Character]
   Swift: r = (i * j + ci + cj) % count; swap(i, r); i++, j--
   ======================= */
CREATE OR ALTER FUNCTION sqids._Shuffle(@alphabet NVARCHAR(255))
RETURNS NVARCHAR(255)
AS
BEGIN
    DECLARE @chars NVARCHAR(255) = @alphabet;
    DECLARE @count INT = LEN(@chars);
    IF @count <= 1 RETURN @chars;

    DECLARE @i INT = 0;
    DECLARE @j INT = @count - 1;

    WHILE @j > 0
    BEGIN
        DECLARE @ci INT = UNICODE(SUBSTRING(@chars, @i + 1, 1));
        DECLARE @cj INT = UNICODE(SUBSTRING(@chars, @j + 1, 1));
        DECLARE @r  INT = (@i * @j + @ci + @cj) % @count;

        IF @r <> @i
        BEGIN
            DECLARE @a NCHAR(1) = SUBSTRING(@chars, @i + 1, 1);
            DECLARE @b NCHAR(1) = SUBSTRING(@chars, @r + 1, 1);
            SET @chars = STUFF(@chars, @i + 1, 1, @b);
            SET @chars = STUFF(@chars, @r + 1, 1, @a);
        END

        SET @i += 1;
        SET @j -= 1;
    END

    RETURN @chars;
END
GO

/* =======================
   splitReverse(offset: Int) -> [Character]
   Swift:
     alphabet = suffix(from: offset) + prefix(offset)
     return reversed()
   ======================= */
CREATE OR ALTER FUNCTION sqids._SplitReverse(@alphabetShuffled NVARCHAR(255), @offset INT)
RETURNS NVARCHAR(255)
AS
BEGIN
    DECLARE @a NVARCHAR(255) = @alphabetShuffled;
    DECLARE @len INT = LEN(@a);
    IF @len = 0 RETURN N'';
    IF @offset < 0 OR @offset >= @len RETURN N'';

    DECLARE @rot NVARCHAR(255) =
        SUBSTRING(@a, @offset + 1, @len - @offset) + SUBSTRING(@a, 1, @offset);

    /* reverse string */
    DECLARE @rev NVARCHAR(255) = N'';
    DECLARE @p INT = LEN(@rot);
    WHILE @p >= 1
    BEGIN
        SET @rev += SUBSTRING(@rot, @p, 1);
        SET @p -= 1;
    END

    RETURN @rev;
END
GO

/* =======================
   toId(number, alphabet) (base conversion)
   Swift uses alphabet = suffix(from: 1) of working alphabet
   ======================= */
CREATE OR ALTER FUNCTION sqids._ToIdBase(@number BIGINT, @alphabet NVARCHAR(255))
RETURNS NVARCHAR(4000)
AS
BEGIN
    IF @number IS NULL OR @number < 0 OR LEN(@alphabet) < 1 RETURN NULL;

    DECLARE @count BIGINT = LEN(@alphabet);
    DECLARE @n BIGINT = @number;
    DECLARE @out NVARCHAR(4000) = N'';

    WHILE 1=1
    BEGIN
        SET @out = SUBSTRING(@alphabet, CONVERT(INT, (@n % @count)) + 1, 1) + @out;
        SET @n = @n / @count;
        IF @n <= 0 BREAK;
    END

    RETURN @out;
END
GO

/* =======================
   toNumber(id, alphabet) with overflow checks like Swift
   Swift:
     acc = acc * count + index
   ======================= */


CREATE OR ALTER FUNCTION sqids._ToNumberBase
(
    @id NVARCHAR(4000),
    @alphabet NVARCHAR(255)
)
RETURNS BIGINT
AS
BEGIN
    IF @id IS NULL OR LEN(@id) = 0 RETURN NULL;

    DECLARE @count BIGINT = LEN(@alphabet);
    IF @count <= 0 RETURN NULL;

    DECLARE @acc BIGINT = 0;
    DECLARE @p INT = 1;
    DECLARE @L INT = LEN(@id);

    WHILE @p <= @L
    BEGIN
        DECLARE @ch NCHAR(1) = SUBSTRING(@id, @p, 1);
        DECLARE @idx INT = sqids._IndexOfChar(@alphabet, @ch);
        IF @idx < 0 RETURN NULL;

        -- Swift overflow checks
        IF @acc > (9223372036854775807 - @idx) / @count RETURN NULL;

        SET @acc = @acc * @count + @idx;
        SET @p += 1;
    END

    RETURN @acc;
END
GO


/* =======================
   Blocklist filtering like init():
   - takes blocklistJson = JSON array of strings
   - keeps only:
     * len >= 3
     * word lowercased consists only of chars from lowercased alphabet
   Returns filtered JSON array (lowercased).
   ======================= */
CREATE OR ALTER FUNCTION sqids._FilterBlocklistJson
(
    @alphabet NVARCHAR(255),
    @blocklistJson NVARCHAR(MAX)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    IF @blocklistJson IS NULL OR ISJSON(@blocklistJson) <> 1 RETURN N'[]';

    DECLARE @alphaLower NVARCHAR(255) = LOWER(@alphabet);

    DECLARE @out NVARCHAR(MAX) = N'[';
    DECLARE @first BIT = 1;

    ;WITH words AS (
        SELECT LOWER(CONVERT(NVARCHAR(255), value)) AS w
        FROM OPENJSON(@blocklistJson)
        WHERE type = 1
    ),
    ok AS (
        SELECT w
        FROM words
        WHERE LEN(w) >= 3
          AND NOT EXISTS (
              SELECT 1
              FROM (
                  /* explode characters by position */
                  SELECT TOP (LEN(w))
                         SUBSTRING(w, v.number, 1) AS c
                  FROM master..spt_values v
                  WHERE v.type='P' AND v.number BETWEEN 1 AND LEN(w)
              ) x
              WHERE CHARINDEX(x.c, @alphaLower) = 0
          )
    )
    SELECT @out = @out +
        CASE WHEN @first=1 THEN N'' ELSE N',' END +
        N'"' + REPLACE(w, N'"', N'\"') + N'"',
        @first = 0
    FROM ok;

    SET @out += N']';
    RETURN @out;
END
GO

/* =======================
   isBlocked(id) 1:1 zur Swift-Logik
   blocklistJson: JSON array of strings (unfiltered ok; we filter like init)
   ======================= */
CREATE OR ALTER FUNCTION sqids._IsBlocked
(
    @id NVARCHAR(4000),
    @alphabet NVARCHAR(255),
    @blocklistJson NVARCHAR(MAX) = NULL
)
RETURNS BIT
AS
BEGIN
    DECLARE @blocked BIT = 0;
    IF @id IS NULL RETURN 0;

    DECLARE @idLower NVARCHAR(4000) = LOWER(@id);

    DECLARE @bl NVARCHAR(MAX) = sqids._FilterBlocklistJson(@alphabet, @blocklistJson);
    IF ISJSON(@bl) <> 1 RETURN 0;

    DECLARE @idLen INT = LEN(@idLower);

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT CONVERT(NVARCHAR(255), value) AS w
        FROM OPENJSON(@bl)
        WHERE type = 1;

    DECLARE @w NVARCHAR(255);

    OPEN cur;
    FETCH NEXT FROM cur INTO @w;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @wLen INT = LEN(@w);

        IF @wLen <= @idLen
        BEGIN
            IF @idLen <= 3 OR @wLen <= 3
            BEGIN
                IF @idLower = @w
                BEGIN
                    SET @blocked = 1; BREAK;
                END
            END
            ELSE IF @w LIKE N'%[0-9]%'  -- word contains digit
            BEGIN
                IF LEFT(@idLower, @wLen) = @w OR RIGHT(@idLower, @wLen) = @w
                BEGIN
                    SET @blocked = 1; BREAK;
                END
            END
            ELSE
            BEGIN
                IF CHARINDEX(@w, @idLower) > 0
                BEGIN
                    SET @blocked = 1; BREAK;
                END
            END
        END

        FETCH NEXT FROM cur INTO @w;
    END

    CLOSE cur; DEALLOCATE cur;
    RETURN @blocked;
END
GO

/* =======================
   encode(numbers) -> String
   Input as JSON array of int64: [1,2,3]
   1:1 zu Swift _encode
   ======================= */
CREATE OR ALTER FUNCTION sqids.EncodeJson
(
    @numbersJson NVARCHAR(MAX)
)
RETURNS NVARCHAR(4000)
AS
BEGIN
    DECLARE @alphabet NVARCHAR(255);
    DECLARE @minLength INT;
    DECLARE @BlocklistJson NVARCHAR(MAX);

    SELECT @alphabet = Alphabet, @minLength = MinLength, @BlocklistJson = BlocklistJson
    FROM sqids.Config
    WHERE ConfigName = N'default';

    IF @alphabet IS NULL RETURN NULL;

    /* "class variables" as DECLAREs */
    DECLARE @minAlphabetLength INT = 3;
    DECLARE @minLengthLimit INT = 255;

    IF @numbersJson IS NULL OR ISJSON(@numbersJson) <> 1 RETURN N'';
    IF @alphabet IS NULL OR LEN(@alphabet) < @minAlphabetLength RETURN NULL;
    IF @minLength < 0 OR @minLength > @minLengthLimit RETURN NULL;

    /* parse numbers */
    DECLARE @Numbers TABLE (idx INT PRIMARY KEY, n BIGINT NOT NULL);
    INSERT INTO @Numbers(idx, n)
    SELECT CONVERT(INT, [key]), TRY_CONVERT(BIGINT, value)
    FROM OPENJSON(@numbersJson)
    WHERE type IN (2,3); -- number

    IF NOT EXISTS (SELECT 1 FROM @Numbers) RETURN N''; -- empty array -> ""

    IF EXISTS (SELECT 1 FROM @Numbers WHERE n < 0) RETURN NULL;

    /* self.alphabet = shuffle(alphabet) */
    DECLARE @selfAlphabet NVARCHAR(255) = sqids._Shuffle(@alphabet);
    DECLARE @alphaCount INT = LEN(@selfAlphabet);
    DECLARE @count BIGINT = @alphaCount; -- Swift Id(alphabet.count)

    DECLARE @increment INT = 0;

    WHILE @increment < @alphaCount
    BEGIN
        /* offset calc:
           numbers.enumerated().reduce(numbers.count) { res + i + ascii(self.alphabet[number%count]) } % self.alphabet.count
           then + increment
        */
       DECLARE @numCount INT = (SELECT COUNT(*) FROM @Numbers);
        DECLARE @offset INT;

        SELECT @offset =
            (
                @numCount
                + ISNULL(SUM(
                    idx
                    + UNICODE(SUBSTRING(@selfAlphabet, CONVERT(INT, (n % @count)) + 1, 1))
                ), 0)
            ) % @alphaCount
        FROM @Numbers;

        SET @offset = (@offset + @increment) % @alphaCount;

        SET @offset = @offset % @alphaCount;
        SET @offset = (@offset + @increment) % @alphaCount;

        /* alphabet = splitReverse(offset) */
        DECLARE @work NVARCHAR(255) = sqids._SplitReverse(@selfAlphabet, @offset);

        /* result starts with self.alphabet[offset] (NOTE: from selfAlphabet, not work) */
        DECLARE @result NVARCHAR(4000) = SUBSTRING(@selfAlphabet, @offset + 1, 1);

        /* loop numbers */
        DECLARE @i INT = 0;
        DECLARE @n BIGINT;

        DECLARE numCur CURSOR LOCAL FAST_FORWARD FOR
            SELECT n FROM @Numbers ORDER BY idx;

        OPEN numCur;
        FETCH NEXT FROM numCur INTO @n;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            /* id = toId(number, alphabet: Array(work.suffix(from: 1))) */
            DECLARE @suffix NVARCHAR(255) = SUBSTRING(@work, 2, LEN(@work) - 1);
            SET @result += sqids._ToIdBase(@n, @suffix);

            /* if not last: append separator work[0], then shuffle(work) */
            IF @i < (SELECT COUNT(*) FROM @Numbers) - 1
            BEGIN
                SET @result += SUBSTRING(@work, 1, 1);
                SET @work = sqids._Shuffle(@work);
            END

            SET @i += 1;
            FETCH NEXT FROM numCur INTO @n;
        END

        CLOSE numCur; DEALLOCATE numCur;

        /* minLength padding 1:1 */
        IF @minLength > LEN(@result)
        BEGIN
            SET @result += SUBSTRING(@work, 1, 1);

            WHILE @minLength > LEN(@result)
            BEGIN
                DECLARE @need INT = @minLength - LEN(@result);
                DECLARE @take INT = IIF(@need < LEN(@work), @need, LEN(@work));

                SET @work = sqids._Shuffle(@work);
                SET @result += SUBSTRING(@work, 1, @take);
            END
        END

        /* blocklist check */
        IF sqids._IsBlocked(@result, @alphabet, @blocklistJson) = 0
            RETURN @result;

        SET @increment += 1;
    END

    RETURN NULL; /* maximumAttemptsReached */
END
GO

/* =======================
   decode(id) -> Ids (JSON)
   1:1 zu Swift decode()
   ======================= */

/* ===== decode(id) -> Ids (JSON) – CHARINDEX case-sensitive ===== */
/* --- BIN2-sicherer Decoder (Swift decode 1:1) --- */
CREATE OR ALTER FUNCTION sqids.DecodeJson
(
    @id NVARCHAR(4000)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
      DECLARE @alphabet NVARCHAR(255);

    SELECT @alphabet = Alphabet
    FROM sqids.Config
    WHERE ConfigName = N'default';

    IF @alphabet IS NULL RETURN NULL;

    IF @id IS NULL OR @id = N'' RETURN N'[]';
    IF @alphabet IS NULL OR LEN(@alphabet) < 3 RETURN N'[]';

    DECLARE @selfAlphabet NVARCHAR(255) = sqids._Shuffle(@alphabet);
    DECLARE @selfAlphabetCS NVARCHAR(255) = @selfAlphabet COLLATE Latin1_General_100_BIN2;

    /* validate: all chars must exist in alphabet (case-sensitive) */
    DECLARE @p INT = 1, @L INT = LEN(@id);
    WHILE @p <= @L
    BEGIN
        IF CHARINDEX(SUBSTRING(@id, @p, 1) COLLATE Latin1_General_100_BIN2, @selfAlphabetCS) = 0
            RETURN N'[]';
        SET @p += 1;
    END

    /* offset = index of first char in shuffled alphabet */
    DECLARE @offset INT =
        CHARINDEX(SUBSTRING(@id, 1, 1) COLLATE Latin1_General_100_BIN2, @selfAlphabetCS) - 1;
    IF @offset < 0 RETURN N'[]';

    DECLARE @work NVARCHAR(255) = sqids._SplitReverse(@selfAlphabet, @offset);
    DECLARE @value NVARCHAR(4000) = SUBSTRING(@id, 2, LEN(@id) - 1);

    DECLARE @out NVARCHAR(MAX) = N'[';
    DECLARE @first BIT = 1;

    WHILE @value <> N''
    BEGIN
        DECLARE @sep NCHAR(1) = SUBSTRING(@work, 1, 1);

        /* IMPORTANT: separator search must be BIN2 */
        DECLARE @posSep INT = CHARINDEX(
            @sep   COLLATE Latin1_General_100_BIN2,
            @value COLLATE Latin1_General_100_BIN2
        );

        DECLARE @chunk NVARCHAR(4000) =
            CASE WHEN @posSep = 0 THEN @value ELSE LEFT(@value, @posSep - 1) END;

        IF @chunk = N'' BREAK; -- padding marker like Swift

        DECLARE @suffix NVARCHAR(255) = SUBSTRING(@work, 2, LEN(@work) - 1);
        DECLARE @num BIGINT = sqids._ToNumberBase(@chunk, @suffix);
        IF @num IS NULL RETURN N'[]';

        SET @out += CASE WHEN @first=1 THEN N'' ELSE N',' END + CONVERT(NVARCHAR(40), @num);
        SET @first = 0;

        IF @posSep = 0
            SET @value = N'';
        ELSE
        BEGIN
            SET @work = sqids._Shuffle(@work);
            SET @value = SUBSTRING(@value, @posSep + 1, LEN(@value) - @posSep);
        END
    END

    SET @out += N']';
    RETURN @out;
END
GO

CREATE OR ALTER FUNCTION sqids.ToId(@n BIGINT)
RETURNS NVARCHAR(4000)
AS
BEGIN
  
    RETURN sqids.EncodeJson(N'[' + CONVERT(NVARCHAR(40), @n) + N']');
END
GO

CREATE OR ALTER FUNCTION sqids.ToNumber(@id NVARCHAR(4000))
RETURNS BIGINT
AS
BEGIN  
    DECLARE @json NVARCHAR(MAX) = sqids.DecodeJson(@id);
    RETURN TRY_CONVERT(BIGINT, JSON_VALUE(@json, '$[0]'));
END
GO
 