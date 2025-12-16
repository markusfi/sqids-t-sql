# Sqids T-SQL

Sqids (pronounced **“squids”**) is a small, deterministic ID-encoding algorithm that generates **short, URL-safe, YouTube-style IDs** from integers and can decode them back to the original numbers.

This repository provides a **pure T-SQL implementation for SQL Server 2019+**, closely following the official Sqids specification and reference implementations (Swift, TypeScript, etc.).

Typical use cases:

- URL-safe public IDs instead of sequential integers
- Link shortening
- Obfuscating database IDs
- Fast round-trip encoding/decoding without lookups
- Deterministic IDs across platforms (when using the same alphabet & settings)

---

## Features

- ✅ Deterministic and reversible (no hashing)
- ✅ Fully compatible with official Sqids implementations
- ✅ Supports single and multiple numbers
- ✅ URL-safe default alphabet
- ✅ Configurable minimum ID length (`minLength`)
- ✅ Built-in **default blocklist** (automatic profanity filtering)
- ✅ No parameters required for encode/decode calls
- ✅ SQL Server 2019 compatible
- ✅ Extensive test coverage in T-SQL

---

## Requirements

- SQL Server **2019 or newer**
- Database collation does **not** need to be case-sensitive  
  (binary comparisons are used internally where required)

---

## Installation

1. Create the `sqids` schema
2. Deploy all objects from this repository:
   - `sqids.Config` table
   - `sqids.Init`
   - `sqids.ToId`
   - `sqids.ToNumber`
   - `sqids.EncodeJson`
   - `sqids.DecodeJson`
   - `sqids.IsBlocked`
   - Test procedures (`sqids.RunTests`, `sqids.RunMinLengthTests`)

No external dependencies are required.

---

## Getting Started

### 1. Initialize Sqids

Initialization stores all settings in the `sqids.Config` table.  
**Encode and decode functions read exclusively from this table.**

```sql
EXEC sqids.Init
    @ConfigName = N'default',
    @Alphabet   = N'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
    @MinLength  = 0,
    @BlocklistJson = NULL;  -- NULL = use built-in default blocklist
```

> ℹ️ If `@BlocklistJson` is `NULL`, the **official Sqids default blocklist** is automatically applied.

---

### 2. Encode Numbers

#### Single number
```sql
SELECT sqids.ToId(12345);
-- e.g. 'Z3mJ'
```

#### Multiple numbers (JSON)
```sql
SELECT sqids.EncodeJson(N'[1,2,3]');
-- e.g. '86Rf07'
```

---

### 3. Decode IDs

#### Single number
```sql
SELECT sqids.ToNumber('Z3mJ');
-- 12345
```

#### Multiple numbers
```sql
SELECT sqids.DecodeJson('86Rf07');
-- [1,2,3]
```

---

## Minimum Length (`minLength`)

You can enforce a minimum ID length during initialization.

```sql
EXEC sqids.Init
    @ConfigName = N'default',
    @Alphabet   = N'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
    @MinLength  = 12,
    @BlocklistJson = NULL;
```

- IDs shorter than `minLength` are **padded deterministically**
- Padding does **not** affect decoding
- Fully compatible with official Sqids behavior

---

## Blocklist

Sqids includes a built-in **default profanity blocklist**, identical to the official implementations.

Rules:

- Blocklist words are case-insensitive
- Words shorter than 3 characters are ignored
- Words containing characters outside the alphabet are ignored
- IDs containing blocked words are **automatically regenerated** using the next increment

You can optionally provide a custom blocklist as JSON:

```sql
EXEC sqids.Init
    @ConfigName = N'default',
    @Alphabet   = N'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
    @MinLength  = 0,
    @BlocklistJson = N'["foo","bar","baz"]';
```

---

## Configuration Storage

All runtime settings are stored in:

```sql
sqids.Config
```

Including:

- Alphabet
- Minimum length
- Blocklist (JSON)

Encode/decode functions **do not accept parameters** and always use the active configuration.

This ensures:

- Consistent behavior across calls
- Simpler usage
- Deterministic results inside SQL

---

## Testing

Two comprehensive test procedures are included.

### 1. Core Tests

```sql
EXEC sqids.RunTests;
```

Covers:

- Alphabet validation
- Single number round-trips
- Multi-number JSON round-trips
- `minLength` enforcement
- Invalid character handling
- Blocklist filtering
- Regression tests up to large ranges

---

### 2. Official MinLength Test Suite

```sql
EXEC sqids.RunMinLengthTests;
```

Covers **official Sqids reference tests**, including:

- Fixed expected IDs
- Incremental `minLength` behavior
- Multi-number deterministic outputs
- Edge cases (0, large values, Int64 max)
- Full encode/decode validation

These tests mirror the **Swift reference test suite**.

---

## Compatibility

This implementation is tested against:

- sqids.org playground
- Official Swift implementation
- Official TypeScript implementation

Using the same alphabet and settings produces **identical IDs**.

---

## License

MIT License

Copyright (c) 2023-present Sqids maintainers  
T-SQL implementation and tests © 2025
