/* Developed with AI assistance from Claude Opus 5.5 (Anthropic) -- 16 Nov 2026 */
/* pfxgen.rex
 *
 * Build the THE and XEDIT versions of the prefix macros from one common
 * source per language (src\pfx<lang>.src), so that a fix is made
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
 *    out\the\pfx<lang>.the
 *    out\xedit\PFX<LANG>.XEDIT
 * The THE acknowledgements are added afterwards by
 * gen\stamp-pfx-credits.rex (the GNUmakefile "pfx" target does both
 * and copies the results to build\).
 *
 * Usage:
 *   rexx gen\pfxgen.rex [lang ...]     default: every src\*.src
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
   /* every definition, and every source no definition uses */
   used = .set~new
   call SysFileTree pfxDir'lang\*.pfx', 'found.', 'FO'
   do i = 1 to found.0
      name = filespec('N', found.i)
      name = name~left(name~length - 4)
      langs = langs name
      def = readDefinition(found.i)
      if def \== .nil then do
         if def['SOURCE'] \== .nil then used~put(def['SOURCE']~lower)
         else used~put(name~lower)
         end
      end
   call SysFileTree srcDir'pfx*.src', 'found.', 'FO'
   do i = 1 to found.0
      name = filespec('N', found.i)
      name = name~substr(4, name~length - 7)
      if \used~hasIndex(name~lower) then langs = langs name
      end
   end

hosts = .array~of(.array~of('THE',   'the',   'pfx', '.the',   .false), ,
                  .array~of('XEDIT', 'xedit', 'PFX', '.XEDIT', .true))
status = 0
do lang over langs~space~makeArray(' ')
   /* phase B: a language definition, if there is one, supplies the
      command blocks that replace the source's #commands directive; its
      :source. names a source shared with other definitions (default:
      the language's own), and its :macro. the macro (default PFX<lang>) */
   def = .nil
   defPath = pfxDir'lang\'lang'.pfx'
   if stream(defPath, 'C', 'QUERY EXISTS') \= '' then do
      def = readDefinition(defPath)
      errors = checkDefinition(def)
      if errors~items > 0 then do
         do e over errors
            say 'pfxgen:' lang'.pfx:' e
            end
         status = 1
         iterate
         end
      end
   srcName = lang
   macro   = 'pfx'lang
   if def \== .nil then do
      if def['SOURCE'] \== .nil then srcName = def['SOURCE']
      if def['MACRO']  \== .nil then macro   = def['MACRO']
      end
   lines = readLines(srcDir'pfx'srcName~lower'.src')
   if lines == .nil then do
      status = 1
      iterate
      end
   do host over hosts
      out = preprocess(lines, host[1], def)
      if out == .nil then do
         say 'pfxgen: pfx'srcName~lower'.src: unbalanced or unknown directive'
         status = 1
         leave
         end
      if host[5] then name = macro~upper
      else name = macro~lower
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
   use strict arg lines, host, def
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
         when directive == '#commands' then do
            if def == .nil then return .nil
            if active then
               do line over emitCommands(def, host)
                  out~append(line)
                  end
            end
         when directive == '#levels' then do
            if def == .nil then return .nil
            if active then out~append(emitLevels(def))
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

/* emitCommands -- Classic Rexx "when" blocks, one per command in the
 * definition, for the macro's command select.  The macro supplies
 * Iline, Cline (the first inserted line), Ccol, Indent, Pad, Op1, the
 * Indent_<unit> variables and the routines Get_mask and (THE)
 * Insert_line or (XEDIT) Add_line. */
::routine emitCommands
   use strict arg def, host
   out = .array~new
   I = '         '
   do cmd over def['CMDS']
      name = cmd['NAME']
      rows = cmd['ROWS']
      cond = "abbrev('"name"',Command_name,"cmd['MIN']")"
      do s over cmd['SYNONYMS']
         cond = cond "| abbrev('"s[1]"',Command_name,"s[2]")"
         end
      out~append(I"when" cond "then do")
      if cmd['LEVEL'] \== .nil then do
         /* a level command: the macro has already required a Level */
         parse value cmd['LEVEL'] with low high .
         out~append(I'   if Level <' low '| Level >' high 'then')
         out~append(I"      call Error_msg 'Expected level from" low 'to' high"'")
         end
      out~append(I"   Eline  = Cline +" rows~items)
      /* the first row, by operand variant */
      if cmd['VARS']~items = 0 then do
         out~append(I'   First  =' rexxText(cmd['FIRST']))
         call emitCursor out, I'   ', cmd['CURSOR'], cmd, def
         end
      else do
         out~append(I'   select')
         anyOther = .false
         do var over cmd['VARS']
            operand = var['OPERAND']
            select
               when operand == '-' then
                  out~append(I"      when Op1 = '' then do")
               when operand == '*' then do
                  out~append(I'      otherwise do')
                  anyOther = .true
                  end
               when operand == '#' then
                  out~append(I"      when datatype(Op1,'W') then do")
               when operand~left(1) == '(' then
                  out~append(I"      when wordpos(Op1,'"operand~substr(2, operand~length - 2)~translate"') > 0 then do")
               otherwise
                  out~append(I"      when abbrev('"operand~translate"',Op1,"var['MIN']") then do")
               end
            out~append(I'         First  =' rexxText(var['FIRST']))
            call emitCursor out, I'         ', var['CURSOR'], cmd, def
            out~append(I'         end')
            end
         if \anyOther then do
            /* no variant takes any other operand: it is an error */
            out~append(I'      otherwise')
            out~append(I"         call Error_msg Op1 'is an invalid option for" name"'")
            end
         out~append(I'      end')
         end
      out~append(I"   COMMAND ':'Iline INPUT Pad || First")
      /* the other rows */
      do row over rows
         cols = unitExpr(row['INDENT'])
         if row['PEND'] \== .nil & row['TEXT']~strip \== '' then do
            /* a body line with placeholder text, e.g. HLASM "opcod ,":
               input it, then set its pending command */
            if cols == '0' then
               out~append(I'   COMMAND          INPUT Pad ||' rexxText(row['TEXT']))
            else
               out~append(I"   COMMAND          INPUT Pad || left(''," cols") ||" rexxText(row['TEXT']))
            out~append(I"   COMMAND          SET   PENDING ON '"row['PEND']"'")
            end
         else if row['PEND'] \== .nil then do
            out~append(I'   Op_col = Indent + 1 +' cols)
            out~append(I'   call Get_mask')
            if host == 'THE' then
               out~append(I"   call Insert_line" row['PEND']", ''")
            else do
               out~append(I'   call Add_line')
               out~append(I"   COMMAND '+1'     SET   PENDING ON '"row['PEND']"'")
               end
            end
         else if cols == '0' then
            out~append(I'   COMMAND          INPUT Pad ||' rexxText(row['TEXT']))
         else
            out~append(I"   COMMAND          INPUT Pad || left(''," cols") ||" rexxText(row['TEXT']))
         end
      out~append(I'   end')
      end
   return out

/* emitCursor -- set Cline and Ccol: a number is an offset in the first
 * row; "body" is the first pending row at its indentation; a row's own
 * :cursor. puts it on that row; no cursor keeps the macro's default. */
::routine emitCursor
   use strict arg out, ind, cursor, cmd, def
   rows = cmd['ROWS']
   do r = 1 to rows~items
      if rows[r]['CURSOR'] \== .nil then do
         out~append(ind'Cline  = Cline +' r)
         out~append(ind'Ccol   = Indent + 1 +' unitExpr(rows[r]['INDENT']) '+' rows[r]['CURSOR'])
         return
         end
      end
   if cursor == .nil then return
   if cursor == 'none' then do
      /* leave the cursor where it is */
      out~append(ind'Ccol   = 0')
      return
      end
   if cursor == 'body' then do
      do r = 1 to rows~items
         if rows[r]['PEND'] \== .nil then do
            out~append(ind'Cline  = Cline +' r)
            out~append(ind'Ccol   = Indent + 1 +' unitExpr(rows[r]['INDENT']))
            return
            end
         end
      return
      end
   out~append(ind'Ccol   = Indent + 1 +' cursor)

/* unitExpr -- "DO" or "SELECT+WHEN" as a Rexx expression of the
 * Indent_<unit> variables; '0' for none */
::routine unitExpr
   use strict arg units
   if units == .nil then return '0'
   expr = ''
   do unit over units~makeArray('+')
      if expr \== '' then expr = expr '+ '
      expr = expr'Indent_'unit
      end
   return expr

/* emitLevels -- for #levels: a Classic Rexx assignment of Level_cmds,
 * the name and minimum abbreviation of each command that takes a level
 * (:level.), for the macro's operand parsing */
::routine emitLevels
   use strict arg def
   pairs = ''
   do cmd over def['CMDS']
      if cmd['LEVEL'] \== .nil then pairs = pairs cmd['NAME'] cmd['MIN']
      end
   return "Level_cmds = '"pairs~strip"'"

/* rexxText -- template text as a Rexx expression: quoted, quotes
 * doubled, %op replaced by the operand Op1, %n by the level Level and
 * %(name) by the macro's variable name, e.g. %(By_reg) */
::routine rexxText
   use strict arg text
   if text == .nil then text = ''
   expr = ''
   do forever
      /* the earliest substitution */
      at = 0
      do tok over .array~of('%op', '%n', '%(')
         p = text~pos(tok)
         if p > 0 & (at = 0 | p < at) then do
            at = p; which = tok
            end
         end
      if at = 0 then leave
      select
         when which == '%op' then do
            len = 3; var = 'Op1'
            end
         when which == '%n' then do
            len = 2; var = 'Level'
            end
         otherwise do
            close = text~pos(')', at)
            var = text~substr(at + 2, close - at - 2)
            len = close - at + 1
            end
         end
      expr = expr"'"text~left(at - 1)~changeStr("'", "''")"' ||" var '|| '
      text = text~substr(at + len)
      end
   return expr"'"text~changeStr("'", "''")"'"

::requires 'pfxdef.cls'
