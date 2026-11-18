# Prefix-macro framework: design

Status, 16 Nov 2026: **phase A is implemented.** Each language has one
source, `pfx\src\pfx<lang>.src`: the macro itself, with the lines that
differ between the editors in `#ifdef THE` / `#ifndef THE` / `#else` /
`#endif` blocks. `pfx\gen\pfxgen.rex` builds `pfx\out\the\pfx<lang>.the`
and `pfx\out\xedit\PFX<LANG>.XEDIT` from it, and `make pfx` adds the THE
acknowledgements (`scripts\stamp-pfx-credits.rex`) and copies changed
macros to `web\source\`. The generated macros were checked byte for byte
against the tested, committed ones. A fix is now made once, in the `.src`.

**Phase B decisions, 17 Nov 2026 (his):**
- Classic Rexx is *only* for the generated macros, which must run under
  CMS, TSO/E-style IBM REXX and Regina. The engine that interprets the
  definitions is ooRexx, part of the generator: it emits the macro code.
- The look-back belongs in a subroutine of the generated macro, at least
  for REXX and PL/I: each language supplies its own look-back routine.
- REXX look-back: skip comment-only lines, block comments, continuation
  lines (the line above ends with a comma) and blank lines. On the line
  that opens a block comment the insert goes 3 columns right of the
  `/`; on a later line of the comment it follows the local context; the
  mask then has no comment delimiters.
- DO FOREVER is preferred in languages that have it (REXX does: TSO/E,
  REXX/VM and OS/2 REXX references).
- First step done: `pfx\lang\rexx.pfx` (the REXX definition) and
  `pfx\gen\pfxdoc.rex` (reads and checks a definition, writes the
  documentation fragment `pfx\out\doc\pfx-<lang>.tex`).

**Status, 17 Nov 2026: phase B is implemented** for REXX, HLASM and GML.
The generator (`gen\pfxgen.rex`, ooRexx) emits each macro's command
blocks from its definition (`lang\rexx.pfx`, `lang\hlasm.pfx`,
`lang\gml.pfx` for PFXGMLW, `lang\dcfgml.pfx` for PFXGMLSS); the
look-back, the indentation rules and the built-in commands stay in
the per-language source (`src\pfx<lang>.src`; both GML definitions
share `src\pfxgml.src`). The generated HLASM macro gave the same
files as the hand-written one in 34 CRXTHE cases. Paths are now
relative to `tools\PrefixMacros`.

**Phase B** (the rest of this document) is still to do: a shared engine
plus one definition file per language, so that adding a language means
writing data, not a macro.
(Written with the help of Claude, an AI engine, for review.)

## Goal

One source per language from which a generator produces, for each host editor:

- the prefix macro (`pfxrexx.the`, `PFXREXX XEDIT`, ...);
- the profile code that issues the `SET PREFIX SYNONYM` commands;
- the documentation fragment for that language (LaTeX, built into
  `Prefix.Macros.pdf` and `.odt`).

Hosts: THE (CRXTHE, macros in Classic Rexx under Regina) and XEDIT
(CMS). Adding a language should mean writing one definition file, not
copying and editing a 500-line macro.

The intent the generated macros must serve: make input of prettyprinted code
easier. In particular:

- every template body line is RIC: a completed body line gets a new body
  line below it, and an untouched one is deleted (decided 16 Nov 2026,
  on the 3270 block model: fill the whole template, then one Enter);
- keyword lines carry no pending command, and the macro inserts the
  full control structure;
- the template mask (`MASK.1`, built from the user's own mask) applies
  only to the body lines the macro adds;
- the cursor starts on the first placeholder;
- indentation follows the language's rules (HLASM: column 10 outside
  control structures, +2 per level; REXX: the documented `Indent_*` values).

## Why generate

The current macros are four hand-maintained files: REXX and HLASM, THE and
XEDIT. Every fix has to be made two to four times, and the copies have drifted:

- `Indent_STRTSRCH` was set in neither copy;
- the ELSE rule was missing;
- the THE copies need Adrian Sutherland's `ADD 1` fix to work at all;
- the documentation was typed from a listing and disagreed with the
  code on indentation and pending commands.

Generating the code and the documentation from one table removes that class
of error: a template row in the documentation is the same data the macro
uses.

## Layout

All under `repos\Personal\pfx\`:

```
pfx\
  lang\        one definition file per language: rexx.pfx, hlasm.pfx, gml.pfx
  core\        host-independent engine source (Classic Rexx), with
               %%HOST:name%% insertion points
  host\        per-host fragments: the.rex, xedit.rex
  gen\         pfxgen.rex -- the generator (ooRexx)
  tests\       THE scenario files (keystrokes + expected screens)
  CREDITS      contributors and what each contributed, by host
```

The generated files go to `pfx\out\the\` and `pfx\out\xedit\`, which are not
tracked. A make target copies them to `web\source\` for publication.
`Documentation\Prefix.Macros.tex` `\input`s the generated
`pfx\out\doc\pfx-<lang>.tex` fragments.

## Language definition files

**Changed 17 Nov 2026 (his):** the tag marker is now the section sign,
`§tag value` (U+00A7, in UTF-8), not `:tag.`. The colon form collided
with the languages themselves (GML `:ROW.`, ooRexx `::class`), and the
reader needed special rules for which tags could follow on a line; `§`
occurs in none of them, so every one starts a tag. The sketch below
still shows the original colon form.

The format is a CMS NAMES-style tagged file: `:tag.value` entries, one entry
per `:cmd.`. It's chosen because the macros come from CMS and because
it's trivial to parse in ooRexx and in OREXX. A sketch for one REXX
command:

```
:lang.REXX  :indent.DO=3 IF=3 label=3 SELECT=1 WHEN=2
:mask.op=. 40=/* 70=*/
:cmd.DO     :min.2  :desc.Insert DO block:
  :row.pend=..  indent=0    text=do
  :row.pend=RI  indent=DO   text=          cursor=op
  :row.pend=    indent=DO   text=end
:cmd.SELect :min.3  :desc.Insert SELECT block:
  :row.pend=    indent=0                text=select
  :row.pend=..  indent=SELECT           text=when . then do   cursor=.
  :row.pend=RIC indent=SELECT+WHEN      text=
  :row.pend=    indent=SELECT+WHEN      text=end
  :row.pend=..  indent=SELECT           text=otherwise do     clause=optional
  :row.pend=RIC indent=SELECT+WHEN      text=                 clause=optional
  :row.pend=    indent=SELECT+WHEN      text=end              clause=optional
  :row.pend=    indent=SELECT           text=end
```

What a definition supplies:

- **Commands:**
  - names, the minimum abbreviation (which gives the
    documentation's case convention, e.g. `SELect`), extra synonyms
    (`OTHER`, `OTHRW`), and the operands accepted (e.g. HLASM `IF`
    condition codes, the `DO` variants).
- **Template rows:**
  - the pending command, and the indentation in named units (`DO`,
    `SELECT+WHEN`) rather than columns;
  - the text, with placeholders (`.`, `?`, `opcod`, `if_test`, `label`);
  - which placeholder gets the cursor;
  - `clause=optional`, to mark rows that disappear together when left
    unchanged: a REXX `otherwise do`, its body and its `end`, or an HLASM
    ELSE with its body.
- **Context rules:**
  - which keywords on the previous line add indentation, e.g. a line
    starting `DO` adds `Indent_DO`;
  - which commands remove it again, e.g. ELSE and ELSEIF go back by
    `Indent_IF`, OTHRWISE by `Indent_WHEN`, ORELSE by `Indent_SEARCH`.

  These are the rules that today are hand-written `select` blocks, and
  where the ELSE and OTHRWISE bugs were.
- **Mask:** what the blank template line contains (REXX: `.` in the
  opcode column, `/*` at 40, `*/` at 70; HLASM: `.`, `,` 8 columns
  later, `*` at 41).
- **Documentation text:** the descriptions and notes for each command.

A language that works differently, such as GML with its single `:` synonym
and the tag as the operand, declares `:dispatch.operand`. The engine
then selects the command from the operand instead of from the synonym.

## Engine

The engine is one Classic Rexx macro body, `core\pfxcore.rex`. It holds
everything the four files duplicate now:

- argument parsing;
- repetition counts;
- EXTRACT;
- indentation from the line before;
- template insertion;
- `..`/RI/RIC;
- the cursor;
- UC/LC;
- STAR/UNSTAR;
- the error message.

The generator inlines it into each output file together with the
language's tables, written as Rexx assignments. XEDIT and THE macros
can't share an external routine library portably, so every generated
macro stands alone.

Behaviour that follows the intent:

- **`..`:** deletes a new line that is unchanged, meaning it still
  equals either the blank mask or its template text with its placeholders
  unreplaced. Today it deletes only blank mask lines, so unused clause
  headers and untouched `opcod ,` lines stay in the file.
- **Optional clauses:** a clause left unchanged (header and body) is
  deleted as a unit, including a REXX clause's own `end`.
- **RI and RIC:** unchanged in meaning. RI repeats; RIC deletes itself
  when left empty.
- **Cursor:** goes to the row marked `cursor=`, on the placeholder
  itself. This fixes the REXX DO and IF cases, which put it in column 1.

### Input flow (decided 15 Nov 2026)

Both editors run every pending prefix command on each Enter, each against
its own line. On a 3270 the user fills in the template and then presses
Enter, so unused parts vanish on that Enter by design. The flow to implement:

- **After a template is inserted:** the cursor goes on the first
  placeholder of the keyword line (`if . then do`: on the `.`). If the
  keyword line has none (`do`, `DO ONCE`), it goes to the first body
  line, at the body's indentation.
- **Enter on a modified keyword line:** the cursor moves to the first
  body line.
- **Enter on a modified body line (RI or RIC):** a new body line is
  inserted after it, with RIC pending, and the cursor moves there.
- **Enter on an empty RIC line where the cursor is:** the line is deleted,
  ending the repeated input. The cursor moves to the next template line
  that still has something pending.
- **The mask's empty comment** (`/*  */` in REXX): it stays. The user can
  delete it or use it as the frame for a block comment.
- **Unused optional clauses** (an empty `else do` / `end`): deferred.

## Host fragments

Each host fragment supplies the same small set of routines, which the
engine calls by name:

| Routine | THE (`host\the.rex`) | XEDIT (`host\xedit.rex`) |
|---|---|---|
| parse prefix arguments | `parse arg Pref Name Func Pline ...` | `parse source` + `parse arg Pref Func Pline ...` |
| indentation overrides | built-in defaults only | `GLOBALV SELECT PFX<lang> GET ...` (CMS) |
| insert blank line | `ADD 1` (Adrian Sutherland's fix) | `INPUT` |
| apply mask | `CLOCATE :1` + `COVERLAY` | `SET MASK IMMED` |
| after-insert adjustment | none | `+1` |
| NOT operator in output | `\` | `¬` (written in the code page used for transfer to CMS) |
| screen refresh | `REFRESH` | `REFRESH` hack for pending lines |

The generator also writes each host's profile code:
- **THE:** a `pfxsetup<lang>.the` setup macro, called from `PROFILE.THE`
  per file type. It sets XEDIT compatibility, the 12-column prefix
  area, mixed case, overwrite mode and the synonyms.
- **XEDIT:** a `PFX<LANG> XEDIT` profile fragment, called from
  `PROFILE XEDIT` per file type.

## Generator

`gen\pfxgen.rex` is in ooRexx, per your conventions. It uses only basic
Rexx plus `.stream`, so it can be adapted to OREXX on ArcaOS if wanted.

```
rexx pfxgen.rex [lang ...]     -- default: every lang\*.pfx
```

For each language it reads `lang\<lang>.pfx`, checks it, and writes:

- `out\the\pfx<lang>.the` and `out\the\pfxsetup<lang>.the`;
- `out\xedit\PFX<LANG>.XEDIT` and the XEDIT profile fragment;
- `out\doc\pfx-<lang>.tex`.

The documentation fragment's `\pfxrow[n]{pending}{text}` rows are
computed from the same template rows and indentation units, so the
documentation can't disagree with the code.

The checks it makes:
- every `cursor=` names a placeholder present in its row's text;
- every command has a description;
- the indentation units are all defined;
- no synonym is defined twice.

The `GNUmakefile` gets two changes:
- a `pfx` target, which runs the generator and copies the published
  files to `web\source\`;
- `docs` now depends on `pfx`.

## Attribution

`CREDITS` records who contributed what, and to which host's output.
Each generated file gets a header built from it.

**THE output:**
```
/* PFXREXX -- REXX prefix macros for THE
   Original XEDIT macros and this framework: Seymour J. Metz
     (H: Shmuel שמואל בן לייביש ולאה), MIT License
   THE adaptation includes changes by Adrian Sutherland from his
     CRXTHE 0.9.1 macro kit (2026-10-27): ADD for blank-line insertion,
     ... (one line per change, from CREDITS)
   For CRXTHE, Adrian Sutherland's fork of THE 4.0 by Mark Hessling.
   Generated by pfxgen.rex from lang\rexx.pfx -- do not edit; edit the
     definition and regenerate. */
```

**XEDIT output:** the same header with only the contributions that
apply to XEDIT. It names you as **Seymour J. Metz (Shmuel)**, in ASCII,
since the file is transferred to CMS.

**Documentation:** gains a "Credits" section built from the same file.

Adrian's changes would be credited per change. His kit states no license
for its patches, so that needs asking (question 1 below).

## Testing

The THE output is tested in CRXTHE under Regina with the console driver
used today. It writes keys straight into THE's console, with the window
hidden, and reads the screen back. Each `tests\<lang>-<cmd>.scn` scenario
lists:

- the file's starting lines;
- the keystrokes (Insert, arrows and so on, typed only where the user
  would type);
- the expected screens, as `prefix | text` tables.

A run compares the actual screens with the expected ones, and a
`make pfx-test` target runs every scenario.

The XEDIT output can't be run here. Its scenarios are written as a
checklist for you to run on CMS, with the same expected screens.

## Plugging in a language

1. Write `lang\<name>.pfx`: commands, template rows, indentation units,
   context rules, mask and descriptions.
2. Run `make pfx`; the generator reports any definition errors.
3. Add scenarios in `tests\`.
4. Add `\input{pfx-<name>}` in `Prefix.Macros.tex`.

No engine change is needed unless the language needs a new kind of
behaviour, such as GML's operand dispatch.

## Candidate languages

His list, 16 Nov 2026: Enterprise PL/I, Python, Ruby, NetRexx, ooRexx. The
HLASM side means the HLASM Toolkit structured macros; PROC (a set of
Assembler H macros) is of historical interest only and is not a
candidate. GML: IBM's GML Starter Set and Waterloo GML differ, so a GML
definition must say which it targets.

What each candidate asks of the definition format and the engine:

- **NetRexx:** close to REXX (`do`/`end`, `select`/`when`/`otherwise`), plus
  `catch` and `finally` clauses and `class`/`method` structure.
- **ooRexx:** the REXX definition plus ooRexx's own structure: `loop`
  and `do ... over`, `select case`, and directives (`::class`,
  `::method`, `::routine`), which start sections rather than blocks
  with an `end`. Best written as an extension of the REXX definition
  rather than a copy.
- **Enterprise PL/I:** `do`/`end`, `if ... then do`, `select`/`when`/
  `otherwise`, `begin`/`end`; source margins (by default columns 2-72)
  matter for the mask and the indentation.
- **Ruby:** keyword blocks closed by `end`; `#` comments.
- **Python:** blocks have no closing keyword; indentation is the
  structure. The definition needs templates with no closing row, and the
  engine must not assume one.

## Migration

1. Write `rexx.pfx` and `hlasm.pfx` from the current macros, with
   today's fixes:
   - ELSE, OTHRWISE and ORELSE return to the right column;
   - a WHEN's END is indented 2 from the WHEN;
   - `Indent_SEARCH` replaces the unset `Indent_STRTSRCH`;
   - the ORELS, OTHER and OTHRW commands are added.
2. Write `gml.pfx` from the documentation (there's no GML macro on the
   site now).
3. Write the engine and both host fragments, starting from Adrian's
   patched THE copies, which run, and your XEDIT originals.
4. Generate, then compare the THE output against today's tested
   behaviour: the scenario files reproduce today's tests.
5. Switch `web\source\` and the documentation to the generated files,
   and retire the hand-maintained macros.

Estimate: two to three sessions. The REXX and HLASM definitions and the
engine are most of the work; the documentation fragments and the profiles
are mechanical once those exist.

## Open questions

1. **License for Adrian's changes:** may they go into MIT-licensed files
   with credit? This needs asking him; I can draft the request.
2. ~~Cursor and rows~~: decided; see "Input flow".
3. **cREXX Level G:** should it be a third host? Adrian maintains Level G
   ports of these workflows independently, so a generated Level G
   version would compete with his rather than replace it.
4. ~~GML macro~~: decided. His PFXGML XEDIT (1985; listing printed
   22 Aug 1989, lines 1-432, complete) is the starting point. Its
   templates are `lang\gml.pfx` (Waterloo GML, PFXGMLW); the DCF GML
   Starter Set Release 4.0 templates are `lang\dcfgml.pfx` (PFXGMLSS);
   both share `src\pfxgml.src`.
5. **XEDIT transfer:** in what form do files go to CMS (code page, record
   format, file name and type)? This decides how the generator writes
   `¬` and names the XEDIT files.
