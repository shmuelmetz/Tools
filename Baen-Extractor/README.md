# Baen-Extractor

ooRexx script that extracts each book in a Baen Free Library archive
to a separate zip file. Supports HTML (`.htm`, `.html`) and PDF
(`.pdf`) book formats.

## Usage

```
rexx baen-extract.rex [/SRC:path] [/OUT:path] [/DRY] [/VERBOSE] [/OVERWRITE]
```

| Option | Default | Description |
|---|---|---|
| `/SRC:path` | `M:\BAEN` | Source directory tree |
| `/OUT:path` | Current directory | Output directory for per-book zips |
| `/DRY` | off | List books found without creating zips |
| `/VERBOSE` | off | Show each file added to each zip |
| `/OVERWRITE` | off | Replace existing output zips |

## Directory structure assumed

```
M:\BAEN\
  BookTitle\          ← book directory → BookTitle.zip
    book.html
    book.pdf
  SeriesName\         ← series grouping (no book files directly)
    Volume1\          ← book directory → Volume1.zip
      vol1.html
    Volume2\
      vol2.html
```

## Requirements

- ooRexx 5.x
- info-zip `zip.exe` (MSYS2, Git for Windows, or standalone)

## Author

Shmuel (Seymour J. Metz) (שְׁמוּאֵל בֵּן ל״ביש) <smetz3@gmu.edu>

## License

MIT — see [LICENSE](LICENSE).
