#!/usr/bin/env rexx
/* Developed with AI assistance from Claude Sonnet 5 (Anthropic) -- 21 Jul 2026 */
/* BookSource.cls
 *
 * Abstract BookSource hierarchy for book inventory/import/export, covering
 * three kinds of sources through one common interface:
 *   - DirectorySource  -- an already-unpacked tree of book folders
 *   - ZipArchiveSource -- a single .zip archive (e.g. a downloaded Book-CD)
 *   - URLSource        -- a remote catalog of bookId -> URL
 *
 * No source-specific interface -- every caller uses the same three methods
 * regardless of which kind of source it's talking to. No CLI-style single-
 * string-argument parsing anywhere: every parameter is a real argument.
 *
 * Zip/network work goes through java.util.zip / java.net via BSF4ooRexx
 * rather than shelling out to zip.exe/unzip.exe/curl.exe -- no external
 * process, no cmd quoting.
 *
 * Requires: a JRE (confirmed present: OpenJDK 21) and BSF4ooRexx (BSF.CLS)
 * on the ooRexx search path. Untested against a live BSF4ooRexx install --
 * this is new code, not a port of something already verified working.
 */

::REQUIRES "BSF.CLS"

::CLASS BookSource ABSTRACT

::METHOD inventory ABSTRACT
    /* () -> .Array of .Directory book descriptors (at least id, name).
       Read-only; never copies or extracts anything. */

::METHOD import ABSTRACT
    /* (bookId, destDir, prefix = '', status = .nil) -> .true/.false.
       Copies/extracts one book's files into destDir, optionally prefixing
       output filenames. If status is given (a mutable .Directory), it's
       populated with ok/count/etc. as a richer alternative to the boolean
       return -- caller's choice, not forced. */

::METHOD export ABSTRACT
    /* (bookIds, destZip, status = .nil) -> .true/.false.
       Packages the given book IDs into a new zip at destZip. */


/* ------------------------------------------------------------------ */
::CLASS DirectorySource SUBCLASS BookSource
    /* Wraps a directory tree of already-unpacked book folders -- one
       subdirectory per book, named by book ID. Subsumes what
       RemovableDriveSource did in session-2026-05-02.rex; that class is
       now redundant with this one (not yet retired -- see chat notes). */

::METHOD init
    expose root
    use strict arg root

::METHOD inventory
    expose root
    books = .Array~new
    if \SysIsFileDirectory(root) then return books
    call SysFileTree root'\*', 'entries.', 'DO'
    do i = 1 to entries.0
        parse var entries.i . . . . entryPath
        bookId = filespec('NAME', strip(entryPath, 'T', '\'))
        book = .Directory~new
        book~id   = bookId
        book~name = bookId
        book~path = entryPath
        books~append(book)
    end
    return books

::METHOD import
    use strict arg bookId, destDir, prefix = '', status = .nil
    expose root
    srcDir = root'\'bookId
    if \SysIsFileDirectory(srcDir) then do
        if status \= .nil then status~ok = .false
        return .false
    end
    call SysFileTree srcDir'\*', 'files.', 'FO'
    copied = 0
    do i = 1 to files.0
        parse var files.i . . . . srcFile
        destFile = destDir'\'prefix || filespec('NAME', srcFile)
        if SysFileCopy(srcFile, destFile) = 0 then copied += 1
    end
    if status \= .nil then do
        status~ok    = copied > 0
        status~count = copied
    end
    return copied > 0

::METHOD export
    use strict arg bookIds, destZip, status = .nil
    expose root
    fisClass = bsf.import("java.io.FileInputStream")
    fosClass = bsf.import("java.io.FileOutputStream")
    zosClass = bsf.import("java.util.zip.ZipOutputStream")
    zeClass  = bsf.import("java.util.zip.ZipEntry")

    fos = fosClass~new(destZip)
    zos = zosClass~new(fos)
    packed = 0
    do bookId over bookIds
        srcDir = root'\'bookId
        if \SysIsFileDirectory(srcDir) then iterate
        call SysFileTree srcDir'\*', 'files.', 'FO'
        do i = 1 to files.0
            parse var files.i . . . . srcFile
            entryName = bookId'/'filespec('NAME', srcFile)
            zos~putNextEntry(zeClass~new(entryName))
            fis = fisClass~new(srcFile)
            fis~transferTo(zos)
            fis~close
            zos~closeEntry
            packed += 1
        end
    end
    zos~close
    if status \= .nil then do
        status~ok    = packed > 0
        status~count = packed
    end
    return packed > 0


/* ------------------------------------------------------------------ */
::CLASS ZipArchiveSource SUBCLASS BookSource
    /* Wraps a single .zip archive (e.g. a downloaded Book-CD) as a source.
       Entries are grouped into books by their top-level path segment
       (BookFolder/chapter1.html -> book id "BookFolder"). */

::METHOD init
    expose zipPath
    use strict arg zipPath

::METHOD inventory
    expose zipPath
    books = .Array~new
    if \SysFileExists(zipPath) then return books
    zfClass = bsf.import("java.util.zip.ZipFile")
    zf = zfClass~new(zipPath)
    entries = zf~entries
    seen = .Set~new
    do while entries~hasMoreElements
        entry = entries~nextElement
        bookId = zipEntryBookId(entry~getName)
        if bookId = '' | seen~hasIndex(bookId) then iterate
        seen~put(bookId)
        book = .Directory~new
        book~id   = bookId
        book~name = bookId
        books~append(book)
    end
    zf~close
    return books

::METHOD import
    use strict arg bookId, destDir, prefix = '', status = .nil
    expose zipPath
    if \SysFileExists(zipPath) then do
        if status \= .nil then status~ok = .false
        return .false
    end
    zfClass  = bsf.import("java.util.zip.ZipFile")
    fosClass = bsf.import("java.io.FileOutputStream")
    zf = zfClass~new(zipPath)
    entries = zf~entries
    extracted = 0
    do while entries~hasMoreElements
        entry = entries~nextElement
        name = entry~getName
        if zipEntryBookId(name) \= bookId then iterate
        if entry~isDirectory then iterate
        destFile = destDir'\'prefix || filespec('NAME', translate(name, '\', '/'))
        ins = zf~getInputStream(entry)
        fos = fosClass~new(destFile)
        ins~transferTo(fos)
        fos~close
        ins~close
        extracted += 1
    end
    zf~close
    if status \= .nil then do
        status~ok    = extracted > 0
        status~count = extracted
    end
    return extracted > 0

::METHOD export
    use strict arg bookIds, destZip, status = .nil
    expose zipPath
    if \SysFileExists(zipPath) then do
        if status \= .nil then status~ok = .false
        return .false
    end
    wanted = .Set~new
    do id over bookIds
        wanted~put(id)
    end
    zfClass  = bsf.import("java.util.zip.ZipFile")
    fosClass = bsf.import("java.io.FileOutputStream")
    zosClass = bsf.import("java.util.zip.ZipOutputStream")
    zeClass  = bsf.import("java.util.zip.ZipEntry")
    zf  = zfClass~new(zipPath)
    fos = fosClass~new(destZip)
    zos = zosClass~new(fos)
    entries = zf~entries
    packed = 0
    do while entries~hasMoreElements
        entry = entries~nextElement
        name = entry~getName
        if entry~isDirectory then iterate
        if \wanted~hasIndex(zipEntryBookId(name)) then iterate
        zos~putNextEntry(zeClass~new(name))
        ins = zf~getInputStream(entry)
        ins~transferTo(zos)
        ins~close
        zos~closeEntry
        packed += 1
    end
    zf~close
    zos~close
    if status \= .nil then do
        status~ok    = packed > 0
        status~count = packed
    end
    return packed > 0


/* ------------------------------------------------------------------ */
::CLASS URLSource SUBCLASS BookSource
    /* Wraps a remote catalog: bookId -> download URL (a .Directory).
       import() downloads via java.net.URL, replacing the curl.exe
       shellout used elsewhere for Book-CD downloads. export() is not
       meaningful for a remote source -- nothing local to package. */

::METHOD init
    expose catalog
    use strict arg catalog

::METHOD inventory
    expose catalog
    books = .Array~new
    do bookId over catalog~allIndexes
        book = .Directory~new
        book~id   = bookId
        book~name = bookId
        book~url  = catalog[bookId]
        books~append(book)
    end
    return books

::METHOD import
    use strict arg bookId, destDir, prefix = '', status = .nil
    expose catalog
    if \catalog~hasIndex(bookId) then do
        if status \= .nil then status~ok = .false
        return .false
    end
    urlClass = bsf.import("java.net.URL")
    fosClass = bsf.import("java.io.FileOutputStream")
    url = urlClass~new(catalog[bookId])
    ins = url~openStream
    destFile = destDir'\'prefix || bookId'.zip'
    fos = fosClass~new(destFile)
    ins~transferTo(fos)
    fos~close
    ins~close
    if status \= .nil then do
        status~ok   = .true
        status~path = destFile
    end
    return .true

::METHOD export
    use strict arg bookIds, destZip, status = .nil
    if status \= .nil then do
        status~ok     = .false
        status~reason = 'URLSource has no local content to export'
    end
    return .false


/* ------------------------------------------------------------------ */
::ROUTINE zipEntryBookId
    /* Zip entry path -> book id, by top-level path segment. Top-level
       files (no subdirectory) don't belong to any book -- returns ''. */
    use arg entryName
    normalized = translate(entryName, '\', '/')
    parse var normalized topSegment '\' rest
    if rest = '' then return ''
    return topSegment
