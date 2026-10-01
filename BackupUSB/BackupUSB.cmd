/* REXX */
/* BACKUPUSB HELP
BackupUSB [archive-drive] [option ...]
BackupUSB HELP      (also ?, -?, /?, -H, in any position)

Zips the local drives C D E F G H I M P Q U W to an archive drive, one archive
per drive (X.ZIP, split parts X.Z01 ..., or X.7Z), and keeps a time-stamped
log, BACKUP.LOG, on the archive drive.

ARCHIVE DRIVE (first term, optional)
  X or X:      use that drive. Its volume label must begin BACKUP and its file
               system must be JFS.
  *            (or omitted) choose from J K L O the eligible drive whose
               BACKUP.LOG is oldest, or which has none.

OPTIONS (any case, any order; the shortest abbreviation is shown in capitals)
Per-drive options apply to every drive, or to one drive when written as
drive:option, e.g. M:LARGEM or M:ARCHIVE=7Z.
  ARCHIVE=ZIP | ARCHIVE=7Z | ZIP | 7Z
               archiver to use (ARC may be abbreviated to three letters).
               Default ZIP.
  D[IRECTORY]  also write a listing of the drive to ARCHIVE:\X.DIR and the
               sizes of its top-level directories to ARCHIVE:\X.SIZ.
  L[ARGEM]     split the M: drive into several archives, one per pdf folder.
  LO[G]        log only: archiver output goes to ARCHIVE:\X.LOG, none shown.
  TEE          log and display, through TEE.
  TES[T]       after each archive, run a test (unzip -t or 7z t) and write its
               output to ARCHIVE:\X.TLOG.
Whole-run options (cannot be limited to one drive):
  A[PPEND]     add to the existing BACKUP.LOG and keep old files; with TEE,
               TEE appends too.
  H[OBBES]     use the Hobbes zip and unzip in H:\Vendors\Hobbes instead of
               the ones found in PATH.
  S[MEDLEY]    use the Smedley zip and unzip in H:\VENDORS\SMEDLEY instead of
               the ones found in PATH.
  V[ERBOSE]    run zip verbosely instead of quietly.
  nnn, nnnK, nnnM, nnnG
               split zip archives into parts of nnn kilobytes, megabytes or
               gigabytes; a bare nnn is megabytes. With LOG or TEE zip also
               gets -sv.
  ONLY dd      back up only the drives named by dd, letters with no spaces,
               e.g. ONLY MP. Implies APPEND, and deletes only the old output
               of those drives.

EXIT CODES
  0  finished; the highest archiver return code is logged.
  2  invalid option, the first term is not a backup drive, or no backup USB
     data key was found.
  4  zip.exe or unzip.exe not found in PATH, or out of memory.
  99 unexpected REXX error.
*/

/* PROGRAM NOTES

   Written for Object REXX (OS/2 orexx): no ::attribute directive, no argument
   defaults in USE ARG, and only the classic string methods. Logical not is
   written with the byte X'AA' (the not sign of this code page), not with a
   backslash.

   Built-in classes used
     .array       CANDIDATES (the possible archive drives), SOURCES (the
                  SourceDrive objects) and the parts of one drive.
     .stem        DATES: the BACKUP.LOG date of each archive drive, indexed
                  by drive letter with colon.
     .directory   SourceDrive class defaults and per-drive overrides, keyed
                  by option name (ARCHIVER SPLITM LISTING TEST REDIRECT).
     .stream      BACKUP.LOG and the X.SIZ file.
     .local       carries the message and return code of die() to Fatal.

   Classes
     Archiver              abstract archiver.
       named (class)       maps ZIP or 7Z to a subclass, else .nil.
       archive             must be overridden; dies with code 4.
     ZipArchiver           archives one drive with zip.
       archive             runs every part returned by parts.
       parts               one ArchivePart, or for M: with LARGEM the root
                           and the pdf folders as separate parts.
     SevenZipArchiver      archives one drive with 7z.
       archive             runs 7z a, then 7z t when TEST is set.
       excludes            turns the drive's exclude patterns into -x! switches.
     SourceDrive           one drive to back up. Class defaults apply to every
                           drive; overrides made by drive:option win.
       init (class)        creates the defaults directory.
       defaults (class)    returns it.
       init                letter, job, exclude patterns.
       letter job exclude  return the corresponding values.
       override            sets an option on this drive only.
       setting             the override, else the class default.
       redirect            REDIRECT setting; TEE gets /A when APPEND is on.
       archiveBase         ARCHIVE:\X, the name stem of the drive's files.
       archive             writes the listing when DIRECTORY, then runs the
                           drive's archiver.
       sizes               writes X.SIZ: the files at the root and the total
                           of each top-level directory.
     ArchivePart           one zip archive of one directory.
       init                drive, directory, archive name, exclude or include
                           list, log-name tag, whether to always keep a TLOG.
       zipFile             archive name with .zip added if missing.
       run                 runs zip, then unzip -t when TEST is set; records
                           the return code in the job; returns it.
     BackupJob             state of the whole run.
       Attributes          archive (archive drive), zipexe, unzipexe, zipopt,
                           p7zipopt, only, append, verbose, split, maxrc,
                           logfile.
       init                sets the defaults.
       selected            true if the drive is in ONLY, or ONLY is empty.
       jobOnly             dies: the option cannot be limited to one drive.
       parseOptions        interprets the option words (see BACKUPUSB HELP).
       openLog             opens BACKUP.LOG and deletes stale files.
       closeLog            closes it.
       findTools           finds zip and unzip in PATH unless HOBBES or SMEDLEY
                           chose them; logs their version.
       logQueue            copies stacked lines into the log.
       setZipOptions       builds the zip option string once.
       msg                 logs a time-stamped line, and shows it unless the
                           mode is Q.
       took                logs an operation with return code and elapsed time.

   Routines
     backupDrive           returns a drive and its BACKUP.LOG date, or ''.
     die                   sets .local FATALTEXT and FATALCODE and raises
                           SYNTAX 98.900, which Fatal turns into the exit code.
     help                  displays the BACKUPUSB HELP comment, using SOURCELINE.

   Variables of the main program
     raw, first, opts      the argument, its first word and the rest.
     info, date, requested, letter, drive
                           work variables of the drive search.
     candidates            J: K: L: O:.
     dates                 BACKUP.LOG date by drive.
     adrive, mindate       the chosen archive drive and the oldest date so far.
     job                   the BackupJob.
     EA                    exclude pattern for extended-attribute files.
     swap                  exclude patterns for swap files and the Firefox lock.
     sources               the SourceDrive objects C D E F G H I M P Q U W.
     known, source, i      work variables of the ONLY check.
   Unquoted symbols used as strings (SPLITM, ARCHIVER, and so on) are never
   assigned, so each is its own upper-case name.

   Exit codes: 0 finished, 2 bad option or drive, 4 missing tool, 99 REXX error.
*/

Call rxfuncadd 'SysLoadFuncs','REXXUTIL','SysLoadFuncs'
call SysLoadFuncs
signal on syntax name Fatal

job = .BackupJob~new
parse source . . me
parse version ver
say me SysGetFileDateTime(me)
say ver
parse arg raw
parse upper var raw first opts

do i = 1 to words(raw)
   if wordpos(word(raw, i)~translate, 'HELP ? -? /? -H') > 0 then do
      call help
      exit 0
      end
   end

candidates = .array~of('J:', 'K:', 'L:', 'O:')
dates      = .stem~new
requested  = ''

if ª'*'~abbrev(first) then do
   info = backupDrive(first)
   if info = '' then do
      say 'First term of' '"'raw'"' 'must be archive drive.'
      exit 2
      end
   parse var info requested date
   dates[requested] = date
   end

do letter over candidates
   info = backupDrive(letter)
   if info ª= '' then do
      parse var info drive date
      dates[drive] = date
      end
   end

adrive  = requested
mindate = 'ff'x
do drive over dates
   if dates[drive] < mindate then do
      if adrive ª= '' then do
         say drive'\backup.log is older than' adrive'\backup.log'
         say 'Skipping' adrive
         end
      adrive  = drive
      mindate = dates[drive]
      end
   end
if adrive = '' then do
   say 'No backup USB data key found'
   exit 2
   end
job~archive = adrive

EA   = '"?? ????. sf"'
swap = 'Home/Mozilla/Firefox/Profiles/*.default/parent.lock'       ,
       '"*\SWAPPER.DAT" *SPF12\*.PAG'
/* 7z's stat() fails outright on this one file (Invalid argument), aborting
   the whole scan; the cause is unexplained -- $ is a legitimate filename
   character, so it isn't that -- but excluding it is simpler than chasing
   the p7zip bug */
hExclude = 'Vendors\ArcaNoae\ASPIROU$'
/* W: fails with ERROR_ACCESS_DENIED trying to read this ~14GB file --
   the user's own renamed copy of a temporary, so it's liable to be open
   or mid-rewrite at backup time; exclude it like SWAPPER.DAT rather than
   fail the whole drive */
wExclude = swap '"*\M.PDF.zip"'

sources = .array~of(.SourceDrive~new('C', job, EA),   ,
                    .SourceDrive~new('D', job, EA),   ,
                    .SourceDrive~new('E', job, swap), ,
                    .SourceDrive~new('F', job, swap), ,
                    .SourceDrive~new('G', job, swap), ,
                    .SourceDrive~new('H', job, hExclude), ,
                    .SourceDrive~new('I', job, ''),   ,
                    .SourceDrive~new('M', job, EA),   ,
                    .SourceDrive~new('P', job, EA),   ,
                    .SourceDrive~new('Q', job, swap), ,
                    .SourceDrive~new('U', job, ''),   ,
                    .SourceDrive~new('W', job, wExclude))

job~parseOptions(opts, sources)

do i = 1 to job~only~length
   letter = job~only~substr(i, 1)
   known  = 0
   do source over sources
      if source~letter = letter then known = 1
      end
   if ªknown then do
      say 'ONLY names unknown drive' letter
      exit 2
      end
   end

job~openLog
job~findTools(sources)
job~setZipOptions

do source over sources
   if job~selected(source~letter) then source~archive
   end
'dir' job~archive '>' job~archive'\dir'

job~msg('')
job~msg('Maximimum return code is' job~maxrc)

job~closeLog
exit

/* die() records the message in .local and raises SYNTAX 98.900, which unwinds
   every method; any other SYNTAX condition is a genuine failure */
Fatal:
text = .local~at('FATALTEXT')
if text ª= .nil then do
   exit .local~at('FATALCODE')
   end
say 'Error' rc 'on line' sigl':' errortext(rc)
say sourceline(sigl)
exit 99

/* ---- classes ---- */

/* An archiver turns one source drive into archives.  Subclasses override
   archive; Archiver~named maps the ARCHIVE= keyword to a subclass. */
::class Archiver

::method named class
use arg name
select
   when name = 'ZIP' then return .ZipArchiver~new
   when name = '7Z'  then return .SevenZipArchiver~new
   otherwise return .nil
   end

::method archive
call die 'Archiver subclass must override archive', 4

::class ZipArchiver subclass Archiver

::method archive
use arg drive
parts = self~parts(drive)
do part over parts
   part~run
   end

/* M: with LARGEM is split into several archives; every other drive is one */
::method parts
use arg drive
letter = drive~letter
base   = drive~archiveBase
root   = letter':\'
if letter = 'M' & drive~setting('SPLITM') then
   return .array~of(                                                                                                     ,
      .ArchivePart~new(drive, root,             base,                  drive~exclude 'M:\pdf\*',            '',           1), ,
      .ArchivePart~new(drive, 'M:\pdf\',        base'.pdf.zip',        '-x@h:\utility\DATA\pdf.ziplist',    'pdf',        1), ,
      .ArchivePart~new(drive, 'M:\pdf\Galaxy\', base'.pdf.Galaxy.zip', '',                                  'pdf.Galaxy', 1), ,
      .ArchivePart~new(drive, 'M:\pdf\IBM',     base'.pdf.IBM.zip',    '-x@h:\utility\DATA\IBM.ziplist',    'pdf.IBM',    1), ,
      .ArchivePart~new(drive, 'M:\pdf\IBM',     base'.pdf.IBM370.zip', '-i@h:\utility\DATA\IBM370.ziplist', 'pdf.IBM370', 1), ,
      .ArchivePart~new(drive, 'M:\pdf\IBM',     base'.pdf.IBMz.zip',   '-i@h:\utility\DATA\IBMz.ziplist',   'pdf.IBMz',   1), ,
      .ArchivePart~new(drive, 'M:\pdf\Math\',   base'.pdf.Math.zip',   '',                                  'pdf.Math',   1))
return .array~of(.ArchivePart~new(drive, root, base, drive~exclude, '', 0))

::class SevenZipArchiver subclass Archiver

::method archive
use arg drive
job    = drive~job
letter = drive~letter
base   = drive~archiveBase
arch   = base'.7z'
'DEL' arch
redirect = drive~redirect
if redirect = '' then do
   pipez = ''
   pipeu = ''
   end
else do
   pipez = redirect base'.log 2>&1'
   pipeu = '>' base'.tlog 2>&1'
   end

cmd = '7z a' job~p7zipopt self~excludes(drive) arch letter':/' pipez
drive~msg(cmd)
call time 'R'
cmd
archrc = rc
job~maxrc = job~maxrc~max(archrc)
job~took('7za', archrc, letter, arch, '', time('E')~trunc)
/* see the matching comment in ArchivePart::run -- 7z's own redirect has
 * already closed base'.log' by this point, so appending here is safe. */
if redirect ª= '' then do
   logline = .stream~new(base'.log')
   logline~open('WRITE APPEND')
   logline~lineout(cmd)
   logline~lineout('rc='archrc)
   logline~close
   end

if drive~setting('TEST') ª= '' then do
   cmd = '7z t' arch pipeu
   drive~msg(cmd)
   call time 'R'
   cmd
   job~took('7z t', rc, arch, '', '', time('E')~trunc)
   end

/* exclude patterns as 7z switches: -x!"pattern" for each, quotes honoured */
::method excludes
use arg drive
result = ''
rest   = drive~exclude~strip
do while rest ª= ''
   if rest~left(1) = '"' then
      parse var rest '"' pat '"' rest
   else
      parse var rest pat rest
   result = result '-x!"'pat'"'
   rest = rest~strip
   end
return result~strip

/* One source drive.  The class-level defaults apply to every drive; a
   drive's own overrides (drive:option) take precedence. */
::class SourceDrive

::method init class
expose defaults
self~init:super
defaults = .directory~new
defaults~put(.ZipArchiver~new, 'ARCHIVER')
defaults~put(0,  'SPLITM')
defaults~put('', 'LISTING')
defaults~put('', 'TEST')
defaults~put('', 'REDIRECT')

::method defaults class
expose defaults
return defaults

::method init
expose letter job exclude overrides
use arg letter, job, exclude
overrides = .directory~new

::method letter
expose letter
return letter

::method job
expose job
return job

::method exclude
expose exclude
return exclude

::method override
expose overrides
use arg key, val
overrides~put(val, key)

::method setting
expose overrides
use arg key
val = overrides~at(key)
if val = .nil then
   val = self~class~defaults~at(key)
return val

::method archiver
return self~setting('ARCHIVER')

/* the redirection for zip output; TEE appends when APPEND was given anywhere */
::method redirect
expose job
redirect = self~setting('REDIRECT')
if redirect = '|tee' & job~append then
   redirect = redirect '/A'
return redirect

/* echoes a command line via the job's log: quiet (log only) except under
   TEE, which shows it on console as well as logging it, per its own
   "log and display" definition */
::method msg
expose job
use arg text
mode = 'Q'
if self~redirect~abbrev('|tee') then
   mode = ''
job~msg(text, mode)

::method archiveBase
expose letter job
arch = job~archive
return arch'\'letter

::method archive
expose letter
if self~setting('LISTING') = 'Y' then do
   base = self~archiveBase
   'DIR' letter':\ /f /s >'base'.dir'
   self~sizes
   end
archiver = self~setting('ARCHIVER')
archiver~archive(self)

::method sizes
expose letter
numeric digits 15
base = self~archiveBase
out  = .stream~new(base'.siz')
out~open('WRITE REPLACE')
rc = SysFileTree(letter':\*', 'top.', 'DO')
out~lineout('# rc='rc 'root directories of' letter':')
rc = SysFileTree(letter':\*', 't.', 'F')
do j = 1 to t.0
   out~lineout(t.j)
   end
out~lineout('# rc='rc 'root files of' letter':')
do i = 1 to top.0
   rc = SysFileTree(top.i'\*', 't.', 'FS')
   sum = 0
   do j = 1 to t.0
      out~lineout(t.j)
      sum = sum + t.j~word(3)
      end
   out~lineout('# total' sum 'bytes' t.0 'files' top.i 'rc='rc)
   end
out~close

/* One zip archive to create from one directory of a source drive */
::class ArchivePart

::method init
expose drive indir arch optx tag tlogAlways
use arg drive, indir, arch, optx, tag, tlogAlways

::method zipFile
expose arch
if arch~translate~right(4) = '.ZIP' then
   return arch
return arch'.zip'

::method run
expose drive indir arch optx tag tlogAlways
job  = drive~job
base = drive~archiveBase
if tag = '' then
   logbase = base
else
   logbase = base'.'tag
redirect = drive~redirect
if redirect = '' then
   pipez = ''
else
   pipez = redirect logbase'.log 2>&1'
if redirect ª= '' | tlogAlways then
   pipeu = '>' logbase'.tlog 2>&1'
else
   pipeu = ''

opts = optx
if opts ª= '' & ªopts~abbrev('-') then
   opts = '-x' opts
zipfile = self~zipFile

cmd = job~zipexe job~zipopt arch indir opts pipez
drive~msg(cmd)
call time 'R'
cmd
ziprc = rc
job~maxrc = job~maxrc~max(ziprc)
job~took('zip', ziprc, indir, zipfile, opts, time('E')~trunc)
/* zip's own redirect (pipez, '>') already truncated and closed logbase'.log'
 * above -- appending the command and its rc here can never clobber
 * whatever zip wrote, quiet or verbose, and guarantees the log is never
 * completely silent about what ran and how it ended. */
if redirect ª= '' then do
   logline = .stream~new(logbase'.log')
   logline~open('WRITE APPEND')
   logline~lineout(cmd)
   logline~lineout('rc='ziprc)
   logline~close
   end

if drive~setting('TEST') ª= '' then do
   cmd = job~unzipexe '-t' zipfile pipeu
   drive~msg(cmd)
   call time 'R'
   cmd
   job~took('unzip -t', rc, zipfile, '', '', time('E')~trunc)
   end
return ziprc

/* Run-wide state: the archive drive, tools, log and return code */
::class BackupJob

::method archive attribute
::method zipexe attribute
::method unzipexe attribute
::method zipopt attribute
::method p7zipopt attribute
::method only attribute
::method append attribute
::method verbose attribute
::method split attribute
::method maxrc attribute
::method logfile attribute

::method init
expose archive zipexe unzipexe zipopt p7zipopt only append verbose split maxrc logfile
archive  = ''
zipexe   = ''
unzipexe = ''
zipopt   = ''
p7zipopt = '-mx=9 -md=128m -ww:\temp'
only     = ''
append   = 0
verbose  = 'q'
split    = ''
maxrc    = 0
logfile  = .nil

::method selected
expose only
parse arg letter
return only = '' | only~pos(letter) > 0

::method jobOnly
parse arg opt
call die 'Option' opt 'applies to the whole run and cannot be limited to one drive', 2

/* Per-drive options set a class default, or an override on one drive */
::method parseOptions
expose zipexe unzipexe only append verbose split
use arg opts, sources
do while opts ª= ''
   parse var opts opt opts

   onDrive = 0
   if opt~length > 2 & opt~pos(':') = 2 then do
      dletter = opt~left(1)
      do source over sources
         if source~letter = dletter then do
            onDrive = 1
            target  = source
            end
         end
      if ªonDrive then
         call die 'Unknown drive in option' opt, 2
      opt = opt~substr(3)
      end

   key = ''
   val = ''
   nondigit = opt~verify('0123456789')
   select
      when opt = 'ONLY' then do
         if onDrive then self~jobOnly(opt)
         parse var opts letters opts
         if letters = '' | ªletters~datatype('U') then
            call die 'ONLY requires drive letters with no spaces, e.g. ONLY MP', 2
         only = only || letters
         end
      when opt~pos('=') > 0 then do
         parse var opt name '=' value
         if name~length < 3 | ª'ARCHIVE'~abbrev(name) then
            call die 'Invalid option' opt, 2
         key = 'ARCHIVER'
         val = .Archiver~named(value)
         if val = .nil then
            call die 'Invalid option' opt'; expected ARCHIVE=ZIP or ARCHIVE=7Z', 2
         end
      when opt = 'ZIP' | opt = '7Z' then do
         key = 'ARCHIVER'
         val = .Archiver~named(opt)
         end
      when 'APPEND'~abbrev(opt) then do
         if onDrive then self~jobOnly(opt)
         append = 1
         end
      when 'DIRECTORY'~abbrev(opt) then do
         key = 'LISTING'
         val = 'Y'
         end
      when 'HOBBES'~abbrev(opt) then do
         if onDrive then self~jobOnly(opt)
         zipexe   = 'H:\Vendors\Hobbes\zip300c\zip.exe'
         unzipexe = 'H:\Vendors\Hobbes\unz600\32-bit\unzip.exe'
         end
      when 'LARGEM'~abbrev(opt) then do
         key = 'SPLITM'
         val = 1
         end
      when 'LOG'~abbrev(opt) then do
         /* log only, no display */
         key = 'REDIRECT'
         val = '>'
         end
      when 'SMEDLEY'~abbrev(opt) then do
         if onDrive then self~jobOnly(opt)
         zipexe   = 'H:\VENDORS\SMEDLEY\ZIP30-OS2-20100814\ZIP.EXE'
         unzipexe = 'H:\VENDORS\SMEDLEY\UNZIP60-OS2-20100530\UNZIP.EXE'
         end
      when opt = 'TEE' then do
         /* log and display */
         key = 'REDIRECT'
         val = '|tee'
         end
      when 'TEST'~abbrev(opt, 3) then do
         /* log unzip -t */
         key = 'TEST'
         val = 'TEST'
         end
      when 'VERBOSE'~abbrev(opt) then do
         if onDrive then self~jobOnly(opt)
         verbose = 'v'
         end
      when nondigit ª= 1 then do
         if onDrive then self~jobOnly(opt)
         unit = ''
         if nondigit > 0 then unit = opt~substr(nondigit)
         select
            when unit = '' & (opt = '' | opt = 0) then
               call die 'Invalid split option' opt, 2
            when unit = '' | (unit~length = 1 & unit~verify('KMG', 'M') > 0) then
               split = opt
            otherwise
               call die 'Invalid split option' opt, 2
            end
         end
      otherwise
         call die 'Invalid option' opt, 2
      end

   if key ª= '' then do
      if onDrive then
         target~override(key, val)
      else
         .SourceDrive~defaults~put(val, key)
      end
   end

if split ª= '' then do
   split = '-s' split
   if .SourceDrive~defaults~at('REDIRECT') ª= '' then
      split = split '-sv'
   end

::method openLog
expose archive logfile append only
logfile = .stream~new(archive'\backup.log')
if append | only ª= '' then
   logfile~open('WRITE APPEND')
else do
   logfile~open('WRITE REPLACE')
   'DEL' archive'\?.*DIR'
   'DEL' archive'\?.*LOG'
   end

'DEL W:\Z*'
'DEL W:\temp\?.ZIP'
'DEL W:\temp\UNSPLIT.ZIP'
'DEL' value('TEMP',,'OS2ENVIRONMENT')'\*.tmp'
if only = '' then do
   'DEL' archive'\?.*Z??'
   'DEL' archive'\?.*7Z'
   end
else do i = 1 to only~length
   letter = only~substr(i, 1)
   'DEL' archive'\'letter'.*DIR'
   'DEL' archive'\'letter'.*LOG'
   'DEL' archive'\'letter'.*Z??'
   'DEL' archive'\'letter'.*7Z'
   end

::method closeLog
expose logfile
logfile~close

/* checks only the tools actually needed by selected drives -- an all-7z
   run must not require zip.exe/unzip.exe, and vice versa */
::method findTools
expose zipexe unzipexe
use arg sources

zipNeeded  = 0
p7zNeeded  = 0
do source over sources
   if self~selected(source~letter) then do
      if source~archiver~isA(.SevenZipArchiver) then p7zNeeded = 1
      else zipNeeded = 1
      end
   end

if zipNeeded then do
   if unzipexe = '' then do
      unzipexe = SysSearchPath('PATH', 'unzip.exe')
      if unzipexe = '' then
         call die 'unzip.exe not found in %PATH%', 4
      self~msg(unzipexe 'found in %PATH%')
      end
   else
      self~msg(unzipexe 'selected by option')
   unzipexe '-v | RXQUEUE'
   self~logQueue
   self~msg('', 'Q')

   if zipexe = '' then do
      zipexe = SysSearchPath('PATH', 'zip.exe')
      if zipexe = '' then
         call die 'zip.exe not found in %PATH%', 4
      self~msg(zipexe 'found in %PATH%')
      end
   else
      self~msg(zipexe 'selected by option')
   zipexe '-v | RXQUEUE'
   self~logQueue
   self~msg('', 'Q')
   end

if p7zNeeded then do
   p7zexe = SysSearchPath('PATH', '7z.exe')
   if p7zexe = '' then
      call die '7z.exe not found in %PATH%', 4
   self~msg(p7zexe 'found in %PATH%')
   '7z | RXQUEUE'
   self~logQueue
   self~msg('', 'Q')
   end

::method logQueue
do queued()
   parse pull text
   self~msg(text, 'Q')
   end

::method setZipOptions
expose zipopt verbose split
zipopt = '-$9rSuy'verbose '-b W:\' split '--display-counts'

::method msg
expose logfile
parse arg text, mode
line = time() text
logfile~lineout(line)
if ª'QUIET'~abbrev(mode~translate, 1) then
   say line

::method took
parse arg op, code, src, dst, optx, secs
if secs = '' then secs = 0
text = op 'of' src
if dst ª= '' then do
   text = text 'to' dst
   select
      when optx~abbrev('-i') then
         text = text 'with include'
      when optx~abbrev('-x') then
         text = text 'with exclude'
      otherwise
         nop
      end
   end
text = text 'took' time('N', secs, 'S') 'with rc='code
self~msg(text)

::routine backupDrive
parse upper arg drive
select
   when '*'~abbrev(drive) then
      return ''
   when drive~length = 2 & drive~right(1) ª= ':' then
      return ''
   when drive~length > 2 then
      return ''
   otherwise
      nop
   end
if drive~length = 1 then
   drive = drive':'
parse value SysDriveInfo(drive) with . . . label
if ªlabel~translate~abbrev('BACKUP') then
   return ''
if SysFileSystemType(drive) ª= 'JFS' then
   return ''
if SysFileTree(drive'\backup.log', 'files.', 'FL') = 2 then
   call die 'Not enought memory', 4
if files.0 = 0 then
   return drive
parse var files.1 date .
return drive date

::routine die
parse arg msg, code
say msg
.local~put(msg, 'FATALTEXT')
.local~put(code, 'FATALCODE')
raise syntax 98.900

/* display the BACKUPUSB HELP comment */
::routine help
found = 0
do n = 1 to sourceline()
   line = sourceline(n)
   if ªfound then do
      if strip(line) = '/* BACKUPUSB HELP' then found = 1
      iterate
      end
   if strip(line) = '*/' then leave
   say line
   end
if ªfound then say 'No help text found.'
