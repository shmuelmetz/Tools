# tools

Scripting tools by Shmuel (Seymour J.) Metz.

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

Shmuel (Seymour J.) Metz <smetz3@gmu.edu>
https://mason.gmu.edu/~smetz3
