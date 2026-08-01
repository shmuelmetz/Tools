#!/usr/bin/env rexx
/* Developed with AI assistance from Claude Sonnet 5 (Anthropic) -- 21 Jul 2026 */
/* baen-extract.rex
 *
 * Extracts each book in a Baen Free Library archive to a separate zip.
 *
 * Supported book formats: HTML (.htm, .html) and PDF (.pdf).
 * Each book directory on the source drive becomes one output zip.
 *
 * Usage:
 *   Preferred, from another REXX program (real REXX arguments, no
 *   command line to build or quote):
 *     call (path_to_this_file) srcDir, outDir, dryRun, verbose, overwrite
 *
 *   Standalone, from a command prompt:
 *     rexx baen-extract.rex [srcDir] [outDir] [dryRun] [verbose] [overwrite]
 *
 * Parameters (all optional, in order):
 *   srcDir     Source directory tree (default: M:\BAEN)
 *   outDir     Output directory for per-book zips (default: current dir)
 *   dryRun     1 = list books found, don't create zips (default: 0)
 *   verbose    1 = show each file added to each zip (default: 0)
 *   overwrite  1 = overwrite existing output zips (default: 0, skip)
 *
 * Requires:
 *   ooRexx 5.x (ArcaOS / Windows)
 *   info-zip zip.exe on PATH or in C:\msys64\usr\bin\
 *
 * Author: Shmuel (Seymour J. Metz) (שמואל בן ל"ביש) <smetz3@gmu.edu>
 * License: MIT
 */

call RxFuncAdd 'SysLoadFuncs', 'REXXUTIL', 'SysLoadFuncs'
call SysLoadFuncs

/* Dual-mode argument parsing. CALL (path) a, b, c, d, e (this file's    */
/* preferred invocation, e.g. from session-2026-05-02.rex) gives         */
/* genuinely separate ARG(n) values -- USE ARG's comma-separated         */
/* defaults are correct REXX-to-REXX call semantics for that case.       */
/* Invoked from a raw OS command line instead (rexx baen-extract.rex     */
/* arg1 arg2 ...), only ARG(1) exists -- ooRexx hands the whole tail to  */
/* it as one string, so that case needs quote-aware splitting instead.   */
if arg(2, 'Exists') then
    use arg srcDir = 'M:\BAEN', outDir = (directory()), dryRun = 0, verbose = 0, overwrite = 0
else do
    rawArgs = arg(1)
    parse var rawArgs 1 firstCh 2
    if firstCh = '"' then
        parse var rawArgs '"' srcDir '"' rawArgs
    else
        parse var rawArgs srcDir rawArgs
    rawArgs = strip(rawArgs)
    parse var rawArgs 1 secondCh 2
    if secondCh = '"' then
        parse var rawArgs '"' outDir '"' rawArgs
    else
        parse var rawArgs outDir rawArgs
    parse var rawArgs dryRun verbose overwrite
    if srcDir    = '' then srcDir    = 'M:\BAEN'
    if outDir    = '' then outDir    = directory()
    if dryRun    = '' then dryRun    = 0
    if verbose   = '' then verbose   = 0
    if overwrite = '' then overwrite = 0
end

/* ── Locate info-zip ──────────────────────────────────────────────── */
zipBin = ''
noIn.0 = 0   /* empty input stem for every ADDRESS SYSTEM ... WITH INPUT STEM  */
             /* call below -- must be set unconditionally, not just inside the */
             /* PATH-lookup fallback: the per-book zip call further down needs */
             /* it too, and zip.exe is normally found on the first candidate   */
             /* check, so that fallback branch doesn't always run.             */
zipCandidates = 'C:\msys64\usr\bin\zip.exe' ,
                'C:\Program Files\Git\usr\bin\zip.exe' ,
                'zip.exe'
do ci = 1 to words(zipCandidates)
    cand = word(zipCandidates, ci)
    if SysFileExists(cand) then do
        zipBin = cand
        leave
    end
end
if zipBin = '' then do
    /* Try PATH lookup via where */
    address system 'where zip.exe' with input stem noIn. output stem whereOut. error stem whereErr.
    if rc = 0 & whereOut.0 > 0 then zipBin = strip(whereOut.1)
end
if zipBin = '' & \dryRun then do
    call emit 'ERROR: zip.exe not found. Install info-zip or use /DRY.'
    exit 1
end

/* ── Validate source ──────────────────────────────────────────────── */
if \SysFileExists(srcDir) then do
    call emit 'ERROR: source directory not found:' srcDir
    exit 1
end

/* ── Ensure output directory ──────────────────────────────────────── */
if \dryRun then
    call SysMkDir outDir

call emit '=== Baen archive extractor ==='
call emit '  Source :' srcDir
call emit '  Output :' outDir
call emit '  Dry run:' (dryRun = 1)
call emit ''

/* ── Find book directories ────────────────────────────────────────── */
/* Strategy: a "book directory" is any directory directly under srcDir
 * that contains at least one .htm/.html or .pdf file.
 * Subdirectories of srcDir that contain only other directories
 * (series groupings) are traversed one level deeper.
 * We do not recurse beyond two levels to avoid false positives.       */

bookDirs = .Array~new

call SysFileTree srcDir'\*', topEntries., 'DSO'
do ti = 1 to topEntries.0
    topDir = strip(topEntries.ti)

    /* Does this directory directly contain book files? */
    if dirHasBooks(topDir) then do
        bookDirs~append(topDir)
    end
    else do
        /* Maybe it's a series grouping; check one level down */
        call SysFileTree topDir'\*', subEntries., 'DSO'
        do si = 1 to subEntries.0
            subDir = strip(subEntries.si)
            if SysFileExists(subDir'\') & dirHasBooks(subDir) then
                bookDirs~append(subDir)
        end
    end
end

if bookDirs~size = 0 then do
    call emit 'No book directories found under' srcDir
    exit 0
end

call emit 'Found' bookDirs~size 'book director'||,
    word('ies y', (bookDirs~size = 1) + 1) || '.'
call emit ''

/* ── Process each book ────────────────────────────────────────────── */
created  = 0
skipped  = 0
errors   = 0

do bookDir over bookDirs
    /* Derive zip name from directory name */
    bookName = filespec('NAME', bookDir)
    outZip   = outDir'\'bookName'.zip'

    if SysFileExists(outZip) & \overwrite then do
        if verbose then call emit '  SKIP (exists): ' outZip
        skipped = skipped + 1
        iterate
    end

    call emit 'Book:' bookName
    if dryRun then do
        /* List files that would be included */
        call SysFileTree bookDir'\*', bookFiles., 'FOS'
        do bfi = 1 to bookFiles.0
            bf = strip(bookFiles.bfi)
            ext = translate(right(bf, 4))
            if ext = '.htm' | ext = 'html' | ext = '.pdf' then
                call emit '  +'  bf
        end
        iterate
    end

    /* Collect book files (HTML + PDF only). SysFileTree itself requires */
    /* a literal stem as its output parameter -- that's fixed by the     */
    /* RexxUtil API, not a style choice -- but the results are folded    */
    /* into one .Array immediately after, rather than kept as three      */
    /* separate stems with no reason to stay separate.                   */
    call SysFileTree bookDir'\*.htm',  htmFiles.,  'FOS'
    call SysFileTree bookDir'\*.html', htmlFiles., 'FOS'
    call SysFileTree bookDir'\*.pdf',  pdfFiles.,  'FOS'
    bookFileList = .Array~new
    do fi = 1 to htmFiles.0;  bookFileList~append(strip(htmFiles.fi));  end
    do fi = 1 to htmlFiles.0; bookFileList~append(strip(htmlFiles.fi)); end
    do fi = 1 to pdfFiles.0;  bookFileList~append(strip(pdfFiles.fi));  end

    if bookFileList~items = 0 then do
        call emit '  NOTE: no .htm/.html/.pdf files found -- skipping'
        iterate
    end

    /* Build combined file list for zip */
    call SysFileDelete outDir'\.__ziplist.tmp'
    call stream outDir'\.__ziplist.tmp', 'C', 'OPEN WRITE REPLACE'
    do bf over bookFileList
        call lineout outDir'\.__ziplist.tmp', bf
        if verbose then call emit '  +' bf
    end
    call stream outDir'\.__ziplist.tmp', 'C', 'CLOSE'

    /* Run zip; -j junk paths (store filenames only, not full path) */
    overwriteFlag = ''
    if overwrite then overwriteFlag = '-u'
    zipCmd = '"'zipBin'" -j -q 'overwriteFlag' "'outZip'" @"'outDir'\.__ziplist.tmp"'
    address system zipCmd with input stem noIn. output stem zOut. error stem zErr.
    zipRc = rc
    /* zOut./zErr. are compelled to be stems by the WITH OUTPUT/ERROR    */
    /* STEM clause itself; fold error lines into an array right after.  */
    zErrList = .Array~new
    do ei = 1 to zErr.0; zErrList~append(strip(zErr.ei)); end

    call SysFileDelete outDir'\.__ziplist.tmp'

    if zipRc = 0 then do
        call emit '  OK:' bookFileList~items 'file(s) ->' outZip
        created = created + 1
    end
    else do
        call emit '  ERROR: zip failed (rc='zipRc') for' bookName
        do ei over zErrList; call emit '    STDERR:' ei; end
        errors = errors + 1
    end
end

call emit ''
call emit '=== Done ==='
call emit '  Created :' created
call emit '  Skipped :' skipped '(already exist; use /OVERWRITE to replace)'
call emit '  Errors  :' errors
exit (errors > 0)


/* ── Helpers ──────────────────────────────────────────────────────── */

dirHasBooks: procedure
    arg d
    call SysFileTree d'\*.htm',  h1., 'FO'
    if h1.0 > 0 then return 1
    call SysFileTree d'\*.html', h2., 'FO'
    if h2.0 > 0 then return 1
    call SysFileTree d'\*.pdf',  h3., 'FO'
    if h3.0 > 0 then return 1
    return 0

emit: procedure
    /* Prints to console either way (so standalone command-line use is   */
    /* unaffected) and, when the caller has set one up via CALL, also    */
    /* appends to .local~baeMessages -- since CALLing this file directly */
    /* (rather than spawning it as a subprocess) doesn't give the caller */
    /* free stdout capture the way ADDRESS SYSTEM's WITH OUTPUT STEM     */
    /* clause does.                                                      */
    parse arg msg
    say msg
    if .local~baeMessages \= .nil then
        .local~baeMessages~append(msg)
    return

