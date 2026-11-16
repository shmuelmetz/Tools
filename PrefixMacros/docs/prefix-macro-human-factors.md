# Prefix macros: human factors analysis

Status: draft for review, 16 Nov 2026.
(Written with the help of Claude, an AI engine, for review.)

## Scope and method

This analysis covers PFXREXX and PFXHLASM, in their THE and XEDIT versions,
and their documentation (`Documentation\Prefix.Macros`).

It is a heuristic review: the macros are judged against their stated purpose,
making input of prettyprinted code easier. It is not a user study. The
evidence comes from:

- the interactive tests run in CRXTHE 0.9.1 under Regina on 15 Nov 2026,
  with keystrokes sent to THE's console and the screens read back;
- reading the macro source;
- your corrections during that work.

The XEDIT versions were not run; findings about XEDIT come from the code
alone.

## The user and the setting

The user is an experienced programmer who already knows XEDIT and the 3270.
The working conditions:

- **Input:** Enter-driven. Each Enter runs every pending prefix command on
  the screen, each against its own line.
- **Editing:** overtype is the norm, with an Insert key. The setup macros
  turn insert mode off.
- **Screen:** a prefix area the setup widens to 12 columns, beside a text
  area of 72 or 80 columns.
- **What the user wants:** code that comes out correctly indented without
  counting columns, while keeping their hands on the keyboard.

Findings are rated **High** (it breaks the goal or loses work), **Medium**
(it costs time or causes errors) or **Low** (it is a nuisance).

## Findings

### 1. (Withdrawn)

An earlier draft said that because each Enter runs every pending command in
a template, the macro dictates the order of input. That was wrong. It
judged the macros as if each line were entered with its own Enter. On a 3270
the user fills in the whole template (keyword, bodies, clauses) and then
presses Enter once. Parts left unused then vanish, which is the design.

### 2. Placeholders can pass as valid code (High, REXX)

A REXX template left unfilled is still syntactically valid:
- In `if . then do`, `.` is a valid Rexx symbol, so the line is accepted and
  the forgotten condition fails at run time, if at all.
- Likewise, `do until .` and `when . then do` run.

HLASM is better here: `opcod`, `R?`, `if_test` and the like are rejected
by the assembler, so a forgotten placeholder is caught.

- **Impact:** a missed placeholder becomes a logic error instead of a syntax
  error.
- **Recommendation:** use a placeholder Rexx rejects, so a forgotten one
  shows up as a syntax error. Choose one that is still a single character to
  overtype, so the edit cost stays the same.

### 3. The cursor didn't start where input starts (Medium; partly fixed)

Before 15 Nov 2026:
- REXX IF left the cursor on the `i` of `if`;
- REXX DO left it in column 1 of the body line.

Typing at the cursor therefore overwrote the keyword or lost the
indentation.

Both are fixed now, in the THE and XEDIT versions. The cursor
starts on the placeholder period, or for DO and DO FOREVER on the body line
at its indentation.

- **Remaining:** your rule that the cursor moves from the keyword to the
  first body line, and from a modified body line to the new one.

### 4. The pending display doesn't match the command name (Medium, THE)

Under THE, the macro marks lines as `CLINE` where the documentation and
XEDIT show `..`.

- **Impact:** the documentation tells the user to look for `..` beside
  lines that will vanish, and THE shows something else.
- **Recommendation:** the THE version should show `..` as well, if THE
  accepts `..` as a pending name. If it doesn't, the documentation needs to
  say that THE shows CLINE.

### 5. Typing over HLASM fields leaves residue (Medium)

The HLASM templates fill several fields with placeholders, as in
`opcod , ,` with a continuation mark. Typing `LR 1,2` straight over that
left `LR 1,2, ,`. The setup sets no tab stops at the HLASM field columns,
so the user can't tab from field to field.

- **Recommendation:**
  - the HLASM setup should set tab stops at the opcode, operand and comment
    columns;
  - each field should have a single placeholder that a Tab lands on.

### 6. Blank lines can't be kept inside a template (Low)

RIC deletes an empty line, which is also how repeated input ends. So a
deliberately blank line inside a block can't be kept: it is taken as the
end of input. The user has to add it afterwards, outside the template's
pending lines.

- **Recommendation:** document it. Alternatively, let a line containing
  only a single blank count as "changed".

### 7. Fixed comment columns (Low, REXX)

The REXX mask puts `/*` in column 40 and `*/` in column 70. You've decided
the empty comment stays: it can be deleted, or used as the frame for a
block comment.

- **Impact:** a statement longer than 38 characters runs into the
  delimiters, and the user has to move them.
- **Recommendation:** make the comment columns per-language parameters in
  the framework, so they can be changed.

### 8. Indentation can't be configured under THE (Low)

Under CMS, GLOBALV variables override the indentation defaults. THE has no
GLOBALV, so under THE the defaults are fixed.

- **Recommendation:** give THE an equivalent, read from the profile, for
  example editor variables set by `pfxsetup` arguments.

### 9. Discoverability (Medium)

The commands are learned from the PDF. Nothing in the editor lists them.
- **Abbreviations:** they differ by language. REXX has SEL, SELE and SELEC;
  HLASM has OTHER and OTHRW.
- **The prefix area limits operands:** forms like `DO B5` or `IF NE` have
  to fit in 12 columns, together with any repetition count.

- **Recommendation:**
  - a `?` prefix command (or a profile-defined PF key) that shows the
    commands and their minimum abbreviations for the current language;
  - generate that list from the same language definition as the code and
    the documentation.

### 10. The two languages behave differently (Medium)

- REXX body lines are blank, masked lines; HLASM body lines carry
  `opcod ,` text.
- Because `..` only deletes lines that still equal the blank mask, the two
  vanish differently: an untouched HLASM `opcod ,` line stays in the file.
- Clause commands that exist in one language are missing in the other.
- Before 15 Nov 2026, your originals defined synonyms (ORELS, OTHER,
  OTHRW) that had no code behind them.

- **Recommendation:** one shared macro body, as in the framework, so the
  two languages differ only in their data.

### 11. Errors and their messages (Low)

Error handling is reasonable: an invalid operand marks the line with
`SET PENDING ERROR` and shows a message.
- **Messages:** they name the problem but not the remedy. "Expected count
  from 1 to 99" is clear; "Unknown prefix subcommand" doesn't say which
  commands are valid.
- **A command that does nothing:** before today's fixes, a synonym with no
  code behind it produced only "Unknown prefix subcommand", which looks like
  a typing error.

- **Recommendation:**
  - error messages that name the valid forms;
  - a generator check that every synonym has code behind it.

### 12. Documentation (Medium; partly fixed)

The documentation was typed from a listing:
- its indentation was unreliable;
- some pending markers didn't match the macros.

On 15 Nov 2026 it got:
- columns that match the macros, shown in monospace with bordered cells;
- GLOBALV qualified as CMS-only;
- entries for ORELS and OTHER/OTHRW;
- a PDF and ODT built from LaTeX.

- **Remaining:**
  - templates don't show where the cursor starts;
  - the search block's pending markers still disagree with the macro;
  - nothing describes the Enter-by-Enter flow, which is what a new user
    most needs.
- **Recommendation:**
  - mark the cursor in each template;
  - add a short worked example of an IF filled in from start to finish,
    with the screen shown as `prefix | text` at each Enter;
  - generate both from the language definitions.

## Priorities

1. Use placeholders that are syntax errors (finding 2). Done 16 Nov 2026:
   the REXX placeholder is now `&`, in the macros and the documentation.
2. Set HLASM tab stops and single placeholders per field (finding 5).
3. Add in-editor help and better messages (findings 9 and 11), generated
   from the definitions.
4. Make the documentation show the cursor (finding 12).
5. Settle the THE pending display (finding 4) and THE configurability
   (finding 8).

These belong to the framework's shared macro body and language
definitions, so they cost little extra once the framework exists.

## Limits of this analysis

- **No user study:** the ratings are judgments, not measurements.
- **XEDIT not run:** findings about XEDIT come from reading the code.
- **Tested on Windows only:** CRXTHE on Windows, through a console driver.
  Its keystroke handling may differ in small ways from a real keyboard or a
  3270.
- **GML not covered:** there's no GML macro to examine.
