/* Developed with AI assistance from Claude (Anthropic) -- 20 Jul 2026 */
/* reconstruct.rex - full script, main routine first, DO-group style */

parse arg argLine

opts = .directory~of(
  "trace"   = .false,, 
  "logFile" = "",, 
  "version" = "1.0.0"
)

args = .directory~of(
  "targetDir" = directory(),, 
  "pkgName"   = "STDIN"
)

do while argLine <> ""
  parse var argLine token argLine

  select
    when token = "--trace" then
      opts["trace"] = .true

    when token = "--help" then
      do
        call showHelp
        exit 0
      end

    when token = "--version" then
      do
        call showVersion opts
        exit 0
      end

    when token = "--log" then
      do
        parse var argLine opts["logFile"] argLine
        if opts["logFile"] = "" then
          do
            say "error: --log requires a filename"
            exit 2
          end
      end

    when token = "--dir" then
      do
        parse var argLine args["targetDir"] argLine
        if args["targetDir"] = "" then
          do
            say "error: --dir requires a directory"
            exit 2
          end
      end

    when token = "--pkg" then
      do
        parse var argLine args["pkgName"] argLine
        if args["pkgName"] = "" then
          do
            say "error: --pkg requires a filename or STDIN"
            exit 2
          end
      end

    /* positional overrides defaults */
    when args["targetDir"] = directory() then
      args["targetDir"] = token

    when args["pkgName"] = "STDIN" then
      args["pkgName"] = token

    otherwise
      do
        say "error: too many positional arguments:" token
        call showHelp
        exit 2
      end
  end
end

/* environment defaults override only if user did not specify */
if args["targetDir"] = directory() then
  do
    envDir = value("RECONSTRUCT_DIR", , "ENVIRONMENT")
    if envDir <> "" then
      args["targetDir"] = envDir
  end

if args["pkgName"] = "STDIN" then
  do
    envPkg = value("RECONSTRUCT_PKG", , "ENVIRONMENT")
    if envPkg <> "" then
      args["pkgName"] = envPkg
  end

if opts["logFile"] = "" then
  do
    envLog = value("RECONSTRUCT_LOG", , "ENVIRONMENT")
    if envLog <> "" then
      opts["logFile"] = envLog
  end

/* RexxUtil is a function package */
call RxFuncAdd "SysLoadFuncs", "RexxUtil", "SysLoadFuncs"
call SysLoadFuncs

/* ensure target directory exists and become current */
call SysMkDir args["targetDir"]
call directory args["targetDir"]

/* open package stream (support STDIN) */
pkgName = args["pkgName"]
if translate(pkgName) = "STDIN" | pkgName = "-" then
  pkgStream = .stream~new("STDIN")
else
  do
    pkgStream = .stream~new(pkgName)
    if pkgStream~query("exists") = "" then
      do
        say "error: package stream does not exist:" pkgName
        exit 2
      end
  end

pkgStream~open("read")

if opts["trace"] then
  do
    say "trace: targetDir =" args["targetDir"]
    say "trace: pkgName   =" args["pkgName"]
    if opts["logFile"] <> "" then
      say "trace: logFile   =" opts["logFile"]
  end

/* open log file if requested */
if opts["logFile"] <> "" then
  do
    logStream = .stream~new(opts["logFile"])
    logStream~open("append")
    call logMessage logStream, "reconstruct start"
  end
else
  logStream = .nil

/* main reconstruction loop */
do while pkgStream~lines > 0
  line = pkgStream~linein
  call reconstructFromPackageLine line, pkgStream, args["targetDir"], opts, logStream
end

pkgStream~close

if logStream \= .nil then
  do
    call logMessage logStream, "reconstruct end"
    logStream~close
  end

call RxFuncDrop "SysLoadFuncs"

exit 0


::routine reconstructFromPackageLine
  use arg line, pkgStream, targetDir, opts, logStream

  /* detect file header */
  if pos("===FILE:", line) = 1 then
    do
      parse var line "===FILE:" relPath "==="

      relPath = strip(relPath)

      if pos(" ", relPath) > 0 then
        do
          say "error: filename contains blanks:" relPath
          return
        end

      fullPath = targetDir || "\" || relPath

      lastSep = lastpos("\", fullPath)
      if lastSep > 0 then
        do
          dirPath = substr(fullPath, 1, lastSep - 1)
          call SysMkDir dirPath
        end

      beginLine = pkgStream~linein
      if strip(beginLine) <> ">>>BEGIN" then
        do
          say "error: expected >>>BEGIN for" relPath
          return
        end

      fileStream = .stream~new(fullPath)
      fileStream~open("write replace")

      do while pkgStream~lines > 0
        content = pkgStream~linein
        if strip(content) = "<<<END" then
          leave
        fileStream~lineout(content)
      end

      fileStream~close

      if opts["trace"] then
        say "trace: wrote file" fullPath

      if logStream \= .nil then
        call logMessage logStream, "file " || fullPath

      return
    end

  return


::routine logMessage
  use arg logStream, text

  if logStream = .nil then return

  logStream~lineout(text)
  return


::routine showHelp
  say "Usage:"
  say "  reconstruct [options] [TARGET_DIR] [PACKAGE_FILE]"
  say
  say "Defaults:"
  say "  TARGET_DIR     current working directory"
  say "  PACKAGE_FILE   STDIN"
  say
  say "Options:"
  say "  --help          Show this help and exit"
  say "  --version       Show version information and exit"
  say "  --trace         Enable trace output"
  say "  --log FILE      Append log messages to FILE"
  say "  --dir DIR       Explicit target directory"
  say "  --pkg FILE      Explicit package file or STDIN"
  say
  say "Environment:"
  say "  RECONSTRUCT_DIR   Default target directory"
  say "  RECONSTRUCT_PKG   Default package file or STDIN"
  say "  RECONSTRUCT_LOG   Default log file"
  return


::routine showVersion
  use arg opts

  say "reconstruct version" opts["version"]
  return

