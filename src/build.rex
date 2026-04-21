/* build.rex
 *
 * Prepend the appropriate platform-specific first line to a script
 * for distribution on a target platform.
 *
 * For Perl:   injects shebang or EXTPROC as line 1
 * For ooRexx: injects EXTPROC or nothing (Windows uses file association)
 *
 * Source files are kept clean (no EXTPROC, no shebang) and this script
 * adds the correct line at build time.
 *
 * Usage:
 *   build --platform <platform> [--perl <path>] [--rexx <path>] file ...
 *
 * Platforms:
 *   os2     OS/2 or ArcaOS
 *   unix    Linux, macOS, BSD
 *   windows Windows (no first-line injection for Windows)
 *
 * Environment variables (override with options):
 *   BUILD_PERL   path to perl binary  (default: perl or /usr/bin/env perl)
 *   BUILD_REXX   path to rexx binary  (default: rexx or /usr/bin/env rexx)
 *
 * Examples:
 *   build --platform unix unobfuscate.pl webzip.rex
 *   build --platform os2  --perl F:\Perl\bin\perl unobfuscate.pl
 *   build --platform windows webzip.rex   (strips any existing first line)
 *
 * Author: Shmuel (Seymour J.) Metz <smetz3@gmu.edu>
 *         https://mason.gmu.edu/~smetz3
 * Repo:   https://github.com/shmuelmetz/tools
 */

call RxFuncAdd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
call SysLoadFuncs

/* Defaults from environment */
perlBin = value('BUILD_PERL',, 'ENVIRONMENT')
rexxBin = value('BUILD_REXX',, 'ENVIRONMENT')
platform = ''
files    = ''

/* Parse arguments */
args = arg(1)
do while args \= ''
    parse var args token args
    select
        when translate(token) = '--PLATFORM' then do
            parse var args platform args
            platform = translate(platform)   /* uppercase for comparison */
            end
        when translate(token) = '--PERL' then do
            parse var args perlBin args
            end
        when translate(token) = '--REXX' then do
            parse var args rexxBin args
            end
        when translate(token) = '--HELP' | token = '?' then do
            call usage
            exit 0
            end
        otherwise
            /* Remaining tokens are filenames */
            if files = '' then files = token
            else files = files token
        end
    end

if platform = '' then do
    say 'ERROR: --platform is required'
    call usage
    exit 1
    end

if files = '' then do
    say 'ERROR: at least one file is required'
    call usage
    exit 1
    end

/* Set defaults for interpreter paths if not supplied */
if perlBin = '' then do
    if platform = 'OS2'     then perlBin = 'perl.exe'
    if platform = 'UNIX'    then perlBin = '/usr/bin/env perl'
    if platform = 'WINDOWS' then perlBin = ''   /* not used */
    end

if rexxBin = '' then do
    if platform = 'OS2'     then rexxBin = 'rexx.exe'
    if platform = 'UNIX'    then rexxBin = '/usr/bin/env rexx'
    if platform = 'WINDOWS' then rexxBin = ''   /* not used */
    end

/* Process each file */
do while files \= ''
    parse var files srcFile files
    call buildFile srcFile, platform, perlBin, rexxBin
    end

exit 0

/* ------------------------------------------------------------------ */
buildFile: procedure
    use arg srcFile, platform, perlBin, rexxBin

    /* Determine file type from extension */
    ext = srcFile~substr(srcFile~lastpos('.')+1)~translate()

    select
        when ext = 'PL'  then type = 'perl'
        when ext = 'REX' then type = 'rexx'
        when ext = 'CMD' then type = 'rexx'   /* legacy OS/2 ooRexx */
        otherwise do
            say 'WARN: unknown extension' ext 'for' srcFile '-- skipping'
            return
            end
        end

    /* Determine the first line to inject */
    firstLine = ''
    select
        when platform = 'OS2' & type = 'perl' then
            firstLine = 'extproc' perlBin '-SW'
        when platform = 'OS2' & type = 'rexx' then
            firstLine = 'extproc' rexxBin
        when platform = 'UNIX' & type = 'perl' then
            firstLine = '#!' || perlBin
        when platform = 'UNIX' & type = 'rexx' then
            firstLine = '#!' || rexxBin
        when platform = 'WINDOWS' then
            firstLine = ''   /* Windows uses file association */
        otherwise
            firstLine = ''
        end

    /* Read source file */
    inStream = .stream~new(srcFile)
    lines = inStream~arrayin()
    inStream~close()

    if lines~items() = 0 then do
        say 'ERROR: could not read' srcFile
        return
        end

    /* Determine output filename */
    outFile = outputName(srcFile, platform, type)
    say 'Building' srcFile '->' outFile '(platform=' platform')'

    /* Write output */
    outStream = .stream~new(outFile)~open('write replace')
    if firstLine \= '' then
        outStream~lineout(firstLine)

    /* Strip any existing shebang or extproc from source */
    startLine = 1
    first = lines[1]~strip('L')
    if first~abbrev('#!') | translate(first~word(1)) = 'EXTPROC' then
        startLine = 2

    do i = startLine to lines~items()
        outStream~lineout(lines[i])
        end

    outStream~close()
    say '  Written:' lines~items() - startLine + 1 'lines' ,
        (if firstLine \= '' then '(+1 injected)' else '(no injection)')
    return

/* ------------------------------------------------------------------ */
outputName: procedure
    use arg srcFile, platform, type
    /* Build output name: srcFile-platform.ext */
    dot  = srcFile~lastpos('.')
    base = srcFile~left(dot-1)
    ext  = srcFile~substr(dot)
    /* Normalize extension for platform */
    select
        when platform = 'WINDOWS' & type = 'perl'  then ext = '.pl'
        when platform = 'WINDOWS' & type = 'rexx'  then ext = '.rex'
        when platform = 'OS2'     then ext = '.cmd'
        when platform = 'UNIX'    then ext = ''   /* no extension on *ix */
        otherwise nop
        end
    return base'-'translate(platform,'abcdefghijklmnopqrstuvwxyz',,
                            'ABCDEFGHIJKLMNOPQRSTUVWXYZ') || ext

/* ------------------------------------------------------------------ */
usage: procedure
    say 'Usage: build --platform <os2|unix|windows> [options] file ...'
    say ''
    say 'Options:'
    say '  --platform  os2|unix|windows  target platform (required)'
    say '  --perl      path              path to perl interpreter'
    say '  --rexx      path              path to rexx interpreter'
    say '  --help                        this message'
    say ''
    say 'Environment:'
    say '  BUILD_PERL  default perl path'
    say '  BUILD_REXX  default rexx path'
    say ''
    say 'Output files are named: basename-platform.ext'
    say '  webzip.rex  -> webzip-unix (no ext), webzip-windows.rex, webzip-os2.cmd'
    return
