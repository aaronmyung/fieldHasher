# FieldHasher.ps1

A flexible, rule-driven hashing tool designed for enterprise data masking tasks, such as anonymisation of PII fields for UAT or data sharing. FieldHasher processes fixed-width text files (or optionally CSV) and applies deterministic hashing to specified character ranges based on prefix-matched rules.

Supports configurable hashing algorithms, optional character filtering, field truncation, output encoding, and multi-threaded processing for performance. Built in PowerShell for portability and transparency.

Licensed under the MIT License.

---

## 🚀 Features

- ✅ Supports MD5, SHA1, SHA256, SHA512 hashing
- ✅ JSON-based field configuration per line prefix (e.g. `00`)
- ✅ Optional CSV mode
- ✅ Salted hashing for added security
- ✅ Character filtering: alpha / numeric / alphanumeric
- ✅ Field truncation and right-padding to match fixed-width format
- ✅ Multi-threaded performance using `ForEach-Object -Parallel`
- ✅ Output encoding toggle: UTF-8 or ANSI
- 🧪 Dry-run mode (no output file written)

---

## 📦 Example Use Case

Hashing fixed-width flat files where each line starts with a prefix (e.g., `00`) indicating the type, and fields within those lines must be deterministically masked for UAT or data sharing.

---

## 🛠️ Usage

```powershell
.\FieldHasher.ps1 `
  -InputFile "raw_data.txt" `
  -OutputFile "hashed_data.txt" `
  -RulesFile "rules.json" `
  -Salt "s0m3s4lt" `
  -HashAlgorithm "SHA256" `
  -Prefix "36" `
  -Encoding "UTF8" `
  -Csv:$false `
  -DryRun:$false
````

---

## 📄 Rules File (`rules.json`)

This file defines which fields to hash based on the prefix of each line. Each prefix maps to an array of field rules:

```json
{
  "00": [
    { "Start": 10, "Length": 12, "Truncate": 10, "Filter": "alphanumeric" },
    { "Start": 50, "Length": 8,  "Truncate": 6,  "Filter": "numeric" }
  ],
  "01": [
    { "Start": 5, "Length": 15, "Truncate": 12, "Filter": "alpha" }
  ]
}
```

* `Start`: Starting character position (0-based)
* `Length`: Number of characters to read
* `Truncate`: Max length of filtered+hashed output
* `Filter`: Type of character filtering before truncation (`alpha`, `numeric`, `alphanumeric`, or none)

---

## 🔒 Hashing Logic

Each field is:

1. Extracted from the line based on the `Start` and `Length`
2. Concatenated with the global `-Salt` (if provided)
3. Hashed using the selected algorithm
4. Filtered based on the configured rule
5. Truncated and right-padded to preserve original field width

---

## ⚙️ Parameters

| Name            | Description                                                |
| --------------- | ---------------------------------------------------------- |
| `InputFile`     | Path to input file (default: `input.txt`)                  |
| `OutputFile`    | Path to output file (default: `output.txt`)                |
| `RulesFile`     | JSON rules file defining field hashing per prefix          |
| `Salt`          | Optional global salt string to append during hashing       |
| `HashAlgorithm` | One of: `MD5`, `SHA1`, `SHA256`, `SHA512` (default: `MD5`) |
| `Prefix`        | Line prefix to match for rule application (e.g., `36`)     |
| `Encoding`      | Output file encoding: `UTF8` or `ANSI` (default: `UTF8`)   |
| `DryRun`        | If set, no output file is written                          |
| `Csv`           | If set, treats input file as CSV instead of fixed-width    |
| `Gui`           | Launches placeholder GUI (not implemented yet)             |

---

## 🧪 Example Rule Execution

A line beginning with `00` like:

```
00JohnDoe    12345678ACME Corp   ...
```

Could be processed to:

```
36A1B2C3D4E5 000123   ACME Corp   ...
```

If rules specify hashing "JohnDoe" to alphanumeric, truncate to 10, and filtering numbers on the 12345678 field.

---

## 💡 Notes

* Uses parallel execution for faster performance on large files
* UTF-8 is recommended unless the system requires ANSI

**Q:** Why MD5?  
**A:** Often sufficient for deterministic hashing in non-cryptographic UAT scenarios. It's fast, widely supported, and easy to implement. Some legacy systems do not support SHA-2 algorithms (like SHA-256), making MD5 a pragmatic choice. That said, SHA-256 is supported and preferred for any sensitive or forward-facing data handling.

**Q:** What if my line has no matching prefix?
**A:** It will be returned unchanged.

**Q:** Can this replace fields with blanks instead of hashes?
**A:** Not currently. You can add this easily in `Process-Line` by modifying the returned value.

---