/* Developed with AI assistance from Claude Opus 5.5 (Anthropic) -- 16 Nov 2026 */
/* pfxgen.rex
 *
 * Build the THE and XEDIT versions of the prefix macros from one common
 * source per language (pfx\src\pfx<lang>.src), so that a fix is made
 * once.  Phase A of docs\prefix-macro-framework.md: the source is the
 * macro itself, with the lines that differ between the editors marked
 *
 *    #ifdef THE         lines for THE only
 *    #ifndef THE        lines for XEDIT only
 *    #else              the other editor's lines
 *    #endif
 *
 * (# in column 1; anything after the directive and its name is a
 * comment).  Blocks may nest.  Phase B replaces the per-language macro
 * body with a shared engine plus a language definition file.
 *
 * Output, CRLF line ends, bytes otherwise unchanged (the XEDIT sources
 * use the CMS not sign, X'AA'):
 *    pfx\out\the\pfx<lang>.the
 *    pfx\out\xedit\PFX<LANG>.XEDIT
 * The THE acknowledgements are added afterwards by
 * scripts\stamp-pfx-credits.rex (the GNUmakefile "pfx" target does both
 * and copies the results to web\source\).
 *
 * Usage:
 *   rexx pfx\gen\pfxgen.rex [lang ...]     default: every pfx\src\*.src
 *
 * Exit code: 0 done, 1 a source has an unbalanced or unknown directive
 * or could not be read.
 *
 * Author: Seymour J. Metz (H: Shmuel)
 * Repo:   https://github.com/shmuelmetz/Personal
 */

call RxFuncAdd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
call SysLoadFuncs

parse source . . thisScript
pfxDir = filespec('L', thisScript)'..\'
srcDir = pfxDir'src\'

parse arg langs
if langs~strip = '' then do
   call SysFileTree srcDir'pfx*.src', 'found.', 'FO'
   do i = 1 to found.0
      name = filespec('N', found.i)
      langs = langs name~substr(4, name~length - 7)
      end
   end

hosts = .array~of(.array~of('THE',   'the',   'pfx', '.the',   .false), ,
                  .array~of('XEDIT', 'xedit', 'PFX', '.XEDIT', .true))
status = 0
do lang over langs~space~makeArray(' ')
   lines = readLines(srcDir'pfx'lang'.src')
   if lines == .nil then do
      status = 1
      iterate
      end
   do host over hosts
      out = preprocess(lines, host[1])
      if out == .nil then do
         say 'pfxgen: pfx'lang'.src: unbalanced or unknown directive'
         status = 1
         leave
         end
      name = host[3]
      if host[5] then name = name || lang~upper
      else name = name || lang~lower
      target = pfxDir'out\'host[2]'\'name || host[4]
      call writeLines target, out
      say 'pfxgen: wrote' target '('out~items 'lines)'
      end
   end
exit status

/* readLines -- the source as an Array of lines (LF or CRLF), or .nil */
::routine readLines
   use strict arg path
   if stream(path, 'C', 'QUERY EXISTS') = '' then do
      say 'pfxgen:' path 'not found'
      return .nil
      end
   s = .stream~new(path)
   s~open('READ')
   data = s~charIn(1, s~chars)
   s~close
   data = data~changeStr('0D0A'x, '0A'x)
   if data~right(1) == '0A'x then data = data~left(data~length - 1)
   return data~makeArray('0A'x)

/* preprocess -- keep the lines that apply when HOST is defined; .nil on
 * an unbalanced or unknown directive.  Each stack entry records whether
 * the enclosing context is active and whether this branch is taken. */
::routine preprocess
   use strict arg lines, host
   out = .array~new
   stack = .queue~new
   active = .true
   do line over lines
      if \line~startsWith('#') then do
         if active then out~append(line)
         iterate
         end
      parse var line directive name .
      select
         when directive == '#ifdef' | directive == '#ifndef' then do
            cond = (name == host)
            if directive == '#ifndef' then cond = \cond
            stack~push(.array~of(active, cond))
            active = active & cond
            end
         when directive == '#else' then do
            if stack~items = 0 then return .nil
            top = stack~peek
            top[2] = \top[2]
            active = top[1] & top[2]
            end
         when directive == '#endif' then do
            if stack~items = 0 then return .nil
            active = stack~pull[1]
            end
         otherwise
            return .nil
         end
      end
   if stack~items \= 0 then return .nil
   return out

/* writeLines -- write the lines with CRLF ends, replacing the file */
::routine writeLines
   use strict arg path, lines
   folder = filespec('D', path)filespec('P', path)
   folder = folder~left(folder~length - 1)
   if \SysIsFileDirectory(folder) then do
      parent = filespec('D', folder)filespec('P', folder)
      call SysMkDir parent~left(parent~length - 1)
      call SysMkDir folder
      end
   s = .stream~new(path)
   s~command('OPEN WRITE REPLACE')
   do line over lines
      s~charOut(line'0D0A'x)
      end
   s~close
