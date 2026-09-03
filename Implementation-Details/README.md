# Implementation-Details

`implementation-details.rex` prints the interpreter's own
self-description: `PARSE SOURCE`, `PARSE VERSION`, and the default
`ADDRESS()` environment in effect at startup. All three vary by
implementation and platform, so this is meant as a quick way to
confirm what you're actually running under -- e.g. before trusting
platform-specific behavior documented in
[Safe-REXX](https://github.com/shmuelmetz/Safe-REXX) (see its "What
flavor of REXX is this?" and ADDRESS sections) -- rather than
hardcoding an assumption.

## Usage

```
rexx implementation-details.rex
```

Takes no options.

## Output

Three labeled sections to stdout:

- **PARSE SOURCE**, split into its three fields: system name (e.g.
  `WindowsNT`, `UNIX`, `OS2`, `TSO`, `CMS`), invocation (`COMMAND`,
  `SUBROUTINE`, or `FUNCTION`), and the full program name/path.
- **PARSE VERSION**, reported as-is. Its exact wording is entirely
  implementation-defined -- only that it names the interpreter and,
  per ANSI X3.274-1996, states the language level it implements (e.g.
  `4.00` = TRL-2, `5.00` = ANSI) is guaranteed, so this script doesn't
  attempt to split it into fields the way it does for SOURCE.
- **Default ADDRESS environment**, i.e. `ADDRESS()` with no argument,
  queried before any `ADDRESS` statement runs -- the platform's
  default host command environment (`CMD` on Windows, a Unix shell
  name, `CMS` or `TSO` on VM/MVS, etc.).

Always exits 0 -- this is a report, not a check.

## Requirements

- Any REXX interpreter implementing `PARSE SOURCE`, `PARSE VERSION`,
  and `ADDRESS()` (all part of the language since TRL-2; no ooRexx- or
  RexxUtil-specific functions are used).

## Author

Shmuel (Seymour J. Metz) (שמואל בן לייביש ולאה) <smetz3@gmu.edu>

## License

MIT — see [LICENSE](LICENSE).
