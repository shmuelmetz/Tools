#!/usr/bin/env rexx
/* next-pending.rex
 *
 * Generic priority-queue bookkeeping: given a flat text queue file and a
 * sentinel-file naming pattern, prints the ID field of the first entry
 * that has not yet been marked done, then exits. Does not perform any
 * work itself and does not write the sentinel -- the caller does the
 * actual work, and only marks the item done (via mark-done.rex, or by
 * writing the sentinel file directly) once that work succeeds. This
 * keeps queue bookkeeping (reusable) separate from what to do with an
 * item (caller/session-specific), per the project's split-reusable-
 * routines-into-Tools convention.
 *
 * Queue file format: one entry per line, pipe-delimited, first field is
 * the ID used to build the sentinel filename:
 *
 *   ID|field2|field3|...
 *
 * Blank lines and lines starting with '#' are ignored.
 *
 * Usage:
 *   rexx next-pending.rex /QUEUE:path /SENTINELDIR:dir /SENTINELPREFIX:text
 *
 * Options:
 *   /QUEUE:path          Queue file to read (required)
 *   /SENTINELDIR:dir     Directory holding sentinel files (required)
 *   /SENTINELPREFIX:text Sentinel filename = dir\prefix<ID>-done
 *                         (default: '.queue-')
 *
 * Output:
 *   On success: prints the full matched line to stdout, exits 0.
 *   If every entry is already done (or the queue is empty): prints
 *   nothing, exits 1.
 *   On error (missing file, bad args): prints a message to stdout
 *   prefixed 'ERROR:', exits 2.
 *
 * Author: Shmuel (Seymour J. Metz) (שְׁמוּאֵל בֵּן ל״ביש) <smetz3@gmu.edu>
 * License: MIT
 */

call RxFuncAdd 'SysLoadFuncs', 'REXXUTIL', 'SysLoadFuncs'
call SysLoadFuncs

parse arg argLine
argLine = strip(argLine)

queueFile      = ''
sentinelDir    = ''
sentinelPrefix = '.queue-'

do while argLine \= ''
    parse var argLine tok argLine
    select
        when translate(left(tok,7))  = '/QUEUE:' then queueFile = substr(tok,8)
        when translate(left(tok,13)) = '/SENTINELDIR:' then sentinelDir = substr(tok,14)
        when translate(left(tok,16)) = '/SENTINELPREFIX:' then sentinelPrefix = substr(tok,17)
        otherwise do
            say 'ERROR: unrecognised option:' tok
            exit 2
        end
    end
end

if queueFile = '' | sentinelDir = '' then do
    say 'ERROR: usage: rexx next-pending.rex /QUEUE:path /SENTINELDIR:dir' ,
        '[/SENTINELPREFIX:text]'
    exit 2
end

if \SysFileExists(queueFile) then do
    say 'ERROR: queue file not found:' queueFile
    exit 2
end

do while lines(queueFile) > 0
    ln = strip(linein(queueFile))
    if ln = '' then iterate
    if left(ln, 1) = '#' then iterate
    parse var ln id '|' .
    id = strip(id)
    if id = '' then iterate
    sentinel = sentinelDir'\'sentinelPrefix||id'-done'
    if \SysFileExists(sentinel) then do
        call stream queueFile, 'C', 'CLOSE'
        say ln
        exit 0
    end
end
call stream queueFile, 'C', 'CLOSE'
exit 1
