# tools

Scripting tools by Seymour J. Metz (H: Shmuel שמואל בן לייביש ולאה).

A mix of ooRexx and Perl utilities. All tools use environment variables
for site-specific defaults; no personal paths are hardcoded.

## Tools

### webzip (ooRexx)

Recursively scan HTML files for linked local resources (href, src, link)
and output a file list suitable for piping to zip.

```
webzip [master.html ...] | zip -@9 output.zip
```

Environment:
- `WEB_ROOT` — local root of web project
- `WEB_MASTERS` — space-separated top-level HTML entry points

### unobfuscate (Perl)

Parse SMTP/MIME messages, decode obfuscation (QP, %xx, integer IPs),
perform DNS/WHOIS lookups, and produce a host report sorted by host
and URL or sender. Useful for analysing spam headers.

```
unobfuscate [options] file ...
```

See `unobfuscate --help` or `unobfuscate --man` for full documentation.

Environment:
- `UNOBFUSCATE_TEMP` — directory for temporary files

### build (ooRexx)

Prepend the platform-appropriate first line to a script for distribution.
Source files are kept clean; this script injects EXTPROC (OS/2),
shebang (*ix), or nothing (Windows) at build time.

```
build --platform <os2|unix|windows> [--perl path] [--rexx path] file ...
```

### groupsio2mbox (ooRexx)

Convert groups.io messages, saved as JSON from the groups.io API's
getmessages call, to an mbox file beside each input. groups.io does not
give members the original mail, so the From address, Message-ID and
threading headers are reconstructed (under the reserved `.invalid`
domain); the date, subject and body come from groups.io unchanged.
Bodies are text/html, quoted-printable; headers are UTF-8 (RFC 6532).
Needs ooRexx 5.0 or later (`json.cls`).

```
groupsio2mbox file.json [file.json ...]
```

### PrefixMacros (REXX macros for THE and XEDIT)

Prefix macros that insert prettyprinted control structures for REXX and
for the HLASM Toolkit structured macros, in THE and in XEDIT under CMS.
Each language has one common source (`src/`) and, as the framework
grows, a definition file (`lang/`); an ooRexx generator (`gen/`) writes
both editors' macros in Classic Rexx. The generated macros are committed
in `build/`; the documentation (PDF, ODT, slides) goes in each release's
zip. `setup/` holds the THE profile and setup macro.

```
make pfx        # regenerate build/ from the sources
make check      # fail if build/ is out of date
make docs       # build the documentation
make release    # zip build/, setup/ and the documentation
make export     # copy them to the web site (PERSONAL_WEB)
```

Design notes: `docs/prefix-macro-framework.md` and
`docs/prefix-macro-human-factors.md`.

## Techniques

Papers on programming techniques, in TeX (build with `xelatex`, twice).

- `Techniques/BXH-switches.tex`: testing successive switches with BXH and
  BXLE (William Collier's technique, IBM TR 00.1412-1, 1966).

## Platform notes

| Platform   | Perl first line              | ooRexx first line      |
|------------|------------------------------|------------------------|
| OS/2 / ArcaOS | `extproc perl.exe -SW`  | `extproc rexx.exe`     |
| *ix / macOS   | `#!/usr/bin/env perl`   | `#!/usr/bin/env rexx`  |
| Windows       | (none -- file assoc)    | (none -- file assoc)   |

Use `build.rex` to produce platform-specific distributions from the
clean source files in `src/`.

## Dependencies

### ooRexx
- ooRexx 4.0 or later: https://sourceforge.net/projects/oorexx/
- RexxUtil (ships with ooRexx)

### Perl
- Perl 5.10.0 or later
- See `docs/CPAN-deps.md` for the full dependency list for unobfuscate

## License

See individual files. unobfuscate has a custom license (unmodified
redistribution free; modified must be open source, no closed-source
dependencies). Other tools are MIT licensed.

## Author

Seymour J. Metz (H: Shmuel שמואל בן לייביש ולאה) <smetz3@gmu.edu>
https://mason.gmu.edu/~smetz3
