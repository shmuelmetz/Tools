/* Developed with AI assistance from Claude Opus 5.5 (Anthropic) -- 17 Nov 2026 */
/* pfxdoc.rex
 *
 * Phase B of docs\prefix-macro-framework.md, first part: read a
 * language definition (pfx\lang\<lang>.pfx), check it, and write the
 * LaTeX documentation fragment for its commands
 * (pfx\out\doc\pfx-<lang>.tex), so that the documented templates come
 * from the same data the engine will use.
 *
 * Definition format: one tag per line, ":tag. value"; a line starting
 * with * is a comment.  :cmd. starts a command; :first. or :var. give
 * its first row (a :var. per operand variant, "-" for no operand, "*"
 * for any other); :row. gives each further row as pend=, indent=
 * (named units joined by +) and text= (the rest of the line).
 *
 * Usage:
 *   rexx pfx\gen\pfxdoc.rex [lang ...]     default: every pfx\lang\*.pfx
 *
 * Exit code: 0 done, 1 a definition has errors (all are listed).
 *
 * Author: Seymour J. Metz (H: Shmuel)
 * Repo:   https://github.com/shmuelmetz/Personal
 */

call RxFuncAdd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
call SysLoadFuncs

parse source . . thisScript
pfxDir = filespec('L', thisScript)'..\'

parse arg langs
if langs~strip = '' then do
   call SysFileTree pfxDir'lang\*.pfx', 'found.', 'FO'
   do i = 1 to found.0
      name = filespec('N', found.i)
      langs = langs name~left(name~length - 4)
      end
   end

status = 0
do lang over langs~space~makeArray(' ')
   def = readDefinition(pfxDir'lang\'lang'.pfx')
   if def == .nil then do
      status = 1
      iterate
      end
   errors = checkDefinition(def)
   if errors~items > 0 then do
      do e over errors
         say 'pfxdoc:' lang'.pfx:' e
         end
      status = 1
      iterate
      end
   target = pfxDir'out\doc\pfx-'lang'.tex'
   call writeDoc target, def
   say 'pfxdoc: wrote' target '('def['CMDS']~items 'commands)'
   end
exit status

/* readDefinition -- a Directory: UNIT (Directory name->columns),
 * CMDS (Array of Directories: NAME MIN DESC FIRST CURSOR VARS ROWS),
 * plus every other top-level tag's value; .nil if unreadable */
::routine readDefinition
   use strict arg path
   if stream(path, 'C', 'QUERY EXISTS') = '' then do
      say 'pfxdoc:' path 'not found'
      return .nil
      end
   s = .stream~new(path)
   s~open('READ')
   lines = s~arrayIn
   s~close
   def = .directory~new
   def['UNIT'] = .directory~new
   def['CMDS'] = .array~new
   cmd = .nil
   do line over lines
      if line~strip = '' | line~left(1) = '*' then iterate
      /* split into :tag. value pairs */
      pairs = .array~new
      rest = line
      do while rest~strip \= ''
         parse var rest ':' tag '.' rest
         nxt = rest~pos(' :')
         if nxt = 0 then do
            value = rest~strip
            rest = ''
            end
         else do
            value = rest~left(nxt)~strip
            rest = rest~substr(nxt + 1)
            end
         pairs~append(.array~of(tag~translate, value))
         end
      first = pairs[1]
      select
         when first[1] == 'UNIT' then
            do item over first[2]~space~makeArray(' ')
               parse var item uname '=' ucols
               def['UNIT'][uname~translate] = ucols
               end
         when first[1] == 'CMD' then do
            cmd = .directory~new
            cmd['NAME'] = first[2]~translate
            cmd['VARS'] = .array~new
            cmd['ROWS'] = .array~new
            do p over pairs
               if p[1] \== 'CMD' then cmd[p[1]] = p[2]
               end
            def['CMDS']~append(cmd)
            end
         when cmd \== .nil & first[1] == 'FIRST' then do
            cmd['FIRST'] = first[2]
            do p over pairs
               if p[1] == 'CURSOR' then cmd['CURSOR'] = p[2]
               end
            end
         when cmd \== .nil & first[1] == 'VAR' then do
            var = .directory~new
            parse value first[2] with var['OPERAND'] var['MIN'] .
            do p over pairs
               if p[1] \== 'VAR' then var[p[1]] = p[2]
               end
            cmd['VARS']~append(var)
            end
         when cmd \== .nil & first[1] == 'ROW' then do
            row = .directory~new
            spec = first[2]
            tpos = spec~pos('text=')
            if tpos > 0 then do
               row['TEXT'] = spec~substr(tpos + 5)
               spec = spec~left(tpos - 1)
               end
            else
               row['TEXT'] = ''
            do kv over spec~space~makeArray(' ')
               parse var kv k '=' v
               row[k~translate] = v
               end
            do p over pairs
               if p[1] == 'CURSOR' then row['CURSOR'] = p[2]
               end
            cmd['ROWS']~append(row)
            end
         otherwise
            def[first[1]] = first[2]
         end
      end
   return def

/* checkDefinition -- an Array of error messages (empty if none) */
::routine checkDefinition
   use strict arg def
   errors = .array~new
   names = .set~new
   do cmd over def['CMDS']
      name = cmd['NAME']
      if names~hasIndex(name) then errors~append('command' name 'defined twice')
      names~put(name)
      if cmd['DESC'] == .nil then errors~append(name': no :desc.')
      if cmd['FIRST'] == .nil & cmd['VARS']~items = 0 then
         errors~append(name': no :first. or :var.')
      if \datatype(cmd['MIN'], 'W') | cmd['MIN'] > name~length then
         errors~append(name': bad :min.')
      do row over cmd['ROWS']
         if row['INDENT'] \== .nil then
            do unit over row['INDENT']~makeArray('+')
               if \def['UNIT']~hasIndex(unit~translate) then
                  errors~append(name': unknown indent unit' unit)
               end
         end
      end
   return errors

/* writeDoc -- the LaTeX fragment: one \item per command, its rows in a
 * pfxexample, indentation from the units' default columns */
::routine writeDoc
   use strict arg path, def
   out = .array~new
   out~append('% Generated by pfx\gen\pfxdoc.rex from pfx\lang\'def['LANG']~lower'.pfx -- do not edit.')
   do cmd over def['CMDS']
      name = cmd['NAME']
      shown = name~left(cmd['MIN']) || name~substr(cmd['MIN'] + 1)~lower
      out~append('\item[{\pfxcommand{'shown'}}]' cmd['DESC']':')
      out~append('')
      out~append('\begin{pfxexample}')
      firstText = cmd['FIRST']
      if firstText == .nil then do
         do var over cmd['VARS']
            if var['OPERAND'] == '-' then firstText = var['FIRST']
            end
         end
      out~append('\pfxrow{}{'texText(firstText)'}')
      do row over cmd['ROWS']
         cols = 0
         if row['INDENT'] \== .nil then
            do unit over row['INDENT']~makeArray('+')
               cols = cols + def['UNIT'][unit~translate]
               end
         pend = row['PEND']
         if pend == .nil then pend = ''
         lead = '\pfxrow'
         if cols > 0 then lead = lead'['cols']'
         out~append(lead'{'pend'}{'texText(row['TEXT'])'}')
         end
      out~append('\end{pfxexample}')
      end
   folder = filespec('D', path)filespec('P', path)
   folder = folder~left(folder~length - 1)
   if \SysIsFileDirectory(folder) then call SysMkDir folder
   s = .stream~new(path)
   s~command('OPEN WRITE REPLACE')
   do line over out
      s~lineOut(line)
      end
   s~close

/* texText -- template text as LaTeX: & escaped, set as a constant */
::routine texText
   use strict arg text
   if text~strip = '' then return ''
   return '\constant{'text~strip~changeStr('&', '\&')'}'
