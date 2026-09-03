#!/usr/bin/env rexx
/* Developed with AI assistance from Claude (Anthropic) -- 03 Sep 2026 */
/* implementation-details.rex
 *
 * Reports the interpreter's own self-description: PARSE SOURCE, PARSE
 * VERSION, and the default ADDRESS environment in effect at startup.
 * Useful for confirming what you're actually running under before
 * relying on dialect- or platform-specific behavior -- see the "What
 * flavor of REXX is this?" and ADDRESS sections of Safe-REXX
 * (https://github.com/shmuelmetz/Safe-REXX) for why each of these
 * varies across implementations and why none of them should be
 * hardcoded on.
 *
 * PARSE SOURCE is three space-delimited tokens (the third is the
 * remainder of the string, so it survives a path containing spaces):
 *   1. system name        e.g. WindowsNT, UNIX, OS2, TSO, CMS
 *   2. invocation          COMMAND, SUBROUTINE, or FUNCTION
 *   3. full program name  the path/name the interpreter was given
 *
 * PARSE VERSION's exact wording is entirely implementation-defined;
 * only that it identifies the interpreter and, per ANSI X3.274-1996,
 * the language level it implements (e.g. "4.00" = TRL-2, "5.00" =
 * ANSI) appear somewhere in the string. It is not three clean fields
 * the way SOURCE is -- this script reports it as-is rather than
 * guessing at a field split that may not hold for every interpreter.
 *
 * ADDRESS() with no argument returns the name of the environment
 * commands are currently sent to. At startup, before any ADDRESS
 * statement, this is the platform's default host command environment
 * (e.g. CMD on Windows, a Unix shell name, CMS or TSO on VM/MVS).
 *
 * Usage:
 *   rexx implementation-details.rex
 *
 * Takes no options. Output goes to stdout; exits 0 always (this is a
 * report, not a check -- it has nothing to fail on).
 *
 * Author: Shmuel (Seymour J. Metz) (שמואל בן לייביש ולאה) <smetz3@gmu.edu>
 * License: MIT
 */

parse source sysName invocation pgmName
parse version verString

say 'PARSE SOURCE:'
say '  System:      ' sysName
say '  Invocation:  ' invocation
say '  Program:     ' pgmName
say ''
say 'PARSE VERSION:'
say '  ' verString
say ''
say 'Default ADDRESS environment:'
say '  ' address()

exit 0
