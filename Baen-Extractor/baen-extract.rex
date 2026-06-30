#!/usr/bin/env rexx
/* baen-extract.rex
 *
 * Extracts each book in a Baen Free Library archive to a separate zip.
 *
 * Supported book formats: HTML (.htm, .html) and PDF (.pdf).
 * Each book directory on the source drive becomes one output zip.
 *
 * Usage:
 *   rexx baen-extract.rex [options]
 *
 * Options:
 *   /SRC:path     Source directory tree (default: M:\BAEN)
 *   /OUT:path     Output directory for per-book zips (default: current dir)
 *   /DRY          Dry run: list books found, don't create zips
 *   /VERBOSE      Show each file added to each zip
 *   /OVERWRITE    Overwrite existing output zips (default: skip)
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

parse arg argLine
argLine = strip(argLine)

/* ── Defaults ─────────────────────────────────────────────────────── */
srcDir   = 'M:\BAEN'
outDir   = directory()
dryRun   = 0
verbose  = 0
overwrite = 0

/* ── Parse arguments ──────────────────────────────────────────────── */
do while argLine \= ''
    parse var argLine tok argLine
    tok = translate(tok)  /* uppercase for comparison */
    select
        when left(tok,5)  = '/SRC:' then srcDir   = substr(tok,6)
        when left(tok,5)  = '/OUT:' then outDir   = substr(tok,6)
        when tok          = '/DRY'  then dryRun   = 1
        when tok          = '/VERBOSE' then verbose = 1
        when tok          = '/OVERWRITE' then overwrite = 1
        otherwise
            say 'WARN: unrecognised option:' tok
    end
end

/* ── Locate info-zip ──────────────────────────────────────────────── */
zipBin = ''
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
    noIn.0 = 0
    address system 'where zip.exe' with input stem noIn. output stem whereOut. error stem whereErr.
    if result = 0 & whereOut.0 > 0 then zipBin = strip(whereOut.1)
end
if zipBin = '' & \dryRun then do
    say 'ERROR: zip.exe not found. Install info-zip or use /DRY.'
    exit 1
end

/* ── Validate source ──────────────────────────────────────────────── */
if \SysFileExists(srcDir) then do
    say 'ERROR: source directory not found:' srcDir
    exit 1
end

/* ── Ensure output directory ──────────────────────────────────────── */
if \dryRun then
    call SysMkDir outDir

say '=== Baen archive extractor ==='
say '  Source :' srcDir
say '  Output :' outDir
say '  Dry run:' (dryRun = 1)
say ''

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
    say 'No book directories found under' srcDir
    exit 0
end

say 'Found' bookDirs~size 'book director'||,
    word('y ies', (bookDirs~size = 1) + 1) || '.'
say ''

/* ── Process each book ────────────────────────────────────────────── */
created  = 0
skipped  = 0
errors   = 0

do bookDir over bookDirs
    /* Derive zip name from directory name */
    bookName = filespec('NAME', bookDir)
    outZip   = outDir'\'bookName'.zip'

    if SysFileExists(outZip) & \overwrite then do
        if verbose then say '  SKIP (exists): ' outZip
        skipped = skipped + 1
        iterate
    end

    say 'Book:' bookName
    if dryRun then do
        /* List files that would be included */
        call SysFileTree bookDir'\*', bookFiles., 'FOS'
        do bfi = 1 to bookFiles.0
            bf = strip(bookFiles.bfi)
            ext = translate(right(bf, 4))
            if ext = '.htm' | ext = 'html' | ext = '.pdf' then
                say '  +'  bf
        end
        iterate
    end

    /* Collect book files (HTML + PDF only) */
    call SysFileTree bookDir'\*.htm',  htmFiles.,  'FOS'
    call SysFileTree bookDir'\*.html', htmlFiles., 'FOS'
    call SysFileTree bookDir'\*.pdf',  pdfFiles.,  'FOS'

    totalFiles = htmFiles.0 + htmlFiles.0 + pdfFiles.0
    if totalFiles = 0 then do
        say '  NOTE: no .htm/.html/.pdf files found -- skipping'
        iterate
    end

    /* Build combined file list for zip */
    call SysFileDelete outDir'\.__ziplist.tmp'
    call stream outDir'\.__ziplist.tmp', 'C', 'OPEN WRITE REPLACE'
    do fi = 1 to htmFiles.0
        call lineout outDir'\.__ziplist.tmp', strip(htmFiles.fi)
        if verbose then say '  +' strip(htmFiles.fi)
    end
    do fi = 1 to htmlFiles.0
        call lineout outDir'\.__ziplist.tmp', strip(htmlFiles.fi)
        if verbose then say '  +' strip(htmlFiles.fi)
    end
    do fi = 1 to pdfFiles.0
        call lineout outDir'\.__ziplist.tmp', strip(pdfFiles.fi)
        if verbose then say '  +' strip(pdfFiles.fi)
    end
    call stream outDir'\.__ziplist.tmp', 'C', 'CLOSE'

    /* Run zip; -j junk paths (store filenames only, not full path) */
    overwriteFlag = ''
    if overwrite then overwriteFlag = '-u'
    zipCmd = '"'zipBin'" -j -q 'overwriteFlag' "'outZip'" @"'outDir'\.__ziplist.tmp"'
    address system zipCmd with input stem noIn. output stem zOut. error stem zErr.
    zipRc = result

    call SysFileDelete outDir'\.__ziplist.tmp'

    if zipRc = 0 then do
        say '  OK:' totalFiles 'file(s) ->' outZip
        created = created + 1
    end
    else do
        say '  ERROR: zip failed (rc='zipRc') for' bookName
        if zErr.0 > 0 then
            do ei = 1 to zErr.0; say '    STDERR:' strip(zErr.ei); end
        errors = errors + 1
    end
end

say ''
say '=== Done ==='
say '  Created :' created
say '  Skipped :' skipped '(already exist; use /OVERWRITE to replace)'
say '  Errors  :' errors
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
