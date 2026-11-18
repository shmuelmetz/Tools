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
      /* a CMS file name has at most 8 characters: PFXOOREXX XEDIT is
         written as PFXOOREX XEDIT */
      if host[5] then name = macro~upper~left(min(macro~length, 8))
      else name = macro~lower
      target = pfxDir'out\'host[2]'\'name || host[4]
      problem = writeLines(target, out)
      if problem \== '' then do
         say 'pfxgen:' problem
         status = 1
         iterate
         end
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
         when directive == '#context' then do
            if def == .nil then return .nil
            if active then
               do line over emitContext(def)
                  out~append(line)
                  end
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
   r = s~command('OPEN WRITE REPLACE')
   if r \== 'READY:' then
      return 'cannot write' path':' r s~description
   do line over lines
      s~charOut(line'0D0A'x)
      end
   s~close
   return ''

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
         out~append(I'   First  =' kwText(def, cmd['FIRST']))
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
            out~append(I'         First  =' kwText(def, var['FIRST']))
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
               out~append(I'   COMMAND          INPUT Pad ||' kwText(def, row['TEXT']))
            else
               out~append(I"   COMMAND          INPUT Pad || left(''," cols") ||" kwText(def, row['TEXT']))
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
            out~append(I'   COMMAND          INPUT Pad ||' kwText(def, row['TEXT']))
         else
            out~append(I"   COMMAND          INPUT Pad || left(''," cols") ||" kwText(def, row['TEXT']))
         end
      out~append(I'   end')
      end
   return out

/* emitCursor -- set Cline and Ccol.  The first row's own cursor comes
 * first: a number is an offset in the first row; "body" is the first
 * pending row at its indentation; "none" leaves the cursor alone.
 * Otherwise a later row's :cursor. puts it on that row; with neither,
 * the macro's default stands. */
::routine emitCursor
   use strict arg out, ind, cursor, cmd, def
   rows = cmd['ROWS']
   if cursor == .nil then
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

/* emitContext -- for #context: Classic Rexx assignments of the
 * definition's look-back data.  Opens_<unit> lists the keywords that
 * open a block indented by that unit (:opens. KEYWORD=unit ...);
 * Line_comment is the line-comment start (:linecomment., '' if none);
 * Continue_chars the characters that continue a line when they end it
 * (:continue. trailing c ...); Anchor_kw and Anchor_cmds (name and
 * minimum of each command) from §anchor KEYWORD command ... */
::routine emitContext
   use strict arg def
   out = .array~new
   opens = .directory~new
   order = .array~new
   spec = def['OPENS']
   if spec == .nil then spec = ''
   do pair over spec~space~makeArray(' ')
      parse var pair keyword '=' unit
      unit = unit~translate
      if \opens~hasIndex(unit) then do
         opens[unit] = ''
         order~append(unit)
         end
      opens[unit] = (opens[unit] keyword~translate)~strip
      end
   do unit over .array~of('DO', 'IF', 'SELECT', 'WHEN')
      if \opens~hasIndex(unit) then opens[unit] = ''
      out~append(('Opens_'unit)~left(15)"= '"opens[unit]"'")
      end
   lc = def['LINECOMMENT']
   if lc == .nil then lc = ''
   out~append('Line_comment'~left(15)"= '"lc~strip"'")
   chars = ''
   mode = 'TRAILING'
   cont = def['CONTINUE']
   if cont \== .nil then do
      parse var cont first rest
      mode = first~translate
      chars = rest~space(0)
      end
   out~append('Continue_mode'~left(15)"= '"mode"'")
   out~append('Continue_chars'~left(15)"= '"chars"'")
   kw = ''
   pairs = ''
   if def['ANCHOR'] \== .nil then do
      parse value def['ANCHOR'] with kw names
      do name over names~space~makeArray(' ')
         do cmd over def['CMDS']
            if cmd['NAME'] == name~translate then pairs = pairs cmd['NAME'] cmd['MIN']
            end
         end
      end
   out~append('Anchor_kw'~left(15)"= '"kw~translate"'")
   out~append('Anchor_cmds'~left(15)"= '"pairs~strip"'")
   /* the options: keyword case (ASIS, LOWER, UPPER) and margins, with
      the group or prefix under which the user overrides them */
   kcase = def['CASE']
   if kcase == .nil then kcase = 'ASIS'
   out~append('Keyword_case'~left(15)"= '"kcase~translate"'")
   parse value def['MARGINS'] with mleft mright .
   if \datatype(mleft, 'W') then mleft = 1
   if \datatype(mright, 'W') then mright = 0
   out~append('Margin_left'~left(15)'=' mleft)
   out~append('Margin_right'~left(15)'=' mright)
   out~append('Option_group'~left(15)"= '"def['MACRO']~upper"'")
   /* the mask: §mask column:text ... op:text -- op is the placeholder
      at the statement column (default '.'), the rest fixed columns */
   items = ''
   op = '.'
   if def['MASK'] \== .nil then
      do item over def['MASK']~space~makeArray(' ')
         parse var item where ':' what
         if where~translate == 'OP' then op = what
         else items = items where what
         end
   out~append('Mask_items'~left(15)"= '"items~strip"'")
   /* the indentation units (§unit), the defaults the user may
      override; REXX's where the definition has none */
   dflt = .directory~of(('DO', 3), ('IF', 3), ('LABEL', 3), ('SELECT', 1), ('WHEN', 2))
   do u over .array~of('DO', 'IF', 'label', 'SELECT', 'WHEN')
      v = def['UNIT'][u~translate]
      if v == .nil then v = dflt[u~translate]
      out~append(('Unit_'u)~left(15)'=' v)
      end
   /* labels: §label colon label (REXX: the label is the base) or
      colon prefix (PL/I: a label prefixes a statement, whose keyword
      governs the indent from the label's column) */
   lmode = 'LABEL'
   if def['LABEL'] \== .nil then lmode = def['LABEL']~word(2)~translate
   out~append('Label_mode'~left(15)"= '"lmode"'")
   /* §closes KEYWORD: after a line starting with it, align with the
      line it closes */
   ekw = ''
   if def['CLOSES'] \== .nil then ekw = def['CLOSES']~word(1)~translate
   out~append('End_kw'~left(15)"= '"ekw"'")
   /* sanity checks: §before COMMAND KEYWORD -- the command may not
      follow KEYWORD within its anchor; §within OPENER CLOSER command
      ... -- the commands need an open OPENER ... CLOSER block */
   bkw = ''
   bcmds = ''
   if def['BEFORE'] \== .nil then do
      parse value def['BEFORE'] with bname bkw .
      bcmds = namePairs(def, bname)
      end
   out~append('Before_cmds'~left(15)"= '"bcmds"'")
   out~append('Before_kw'~left(15)"= '"bkw~translate"'")
   rules = ''
   if def['WITHINS'] \== .nil then
      do w over def['WITHINS']
         parse var w opener closer names
         if rules \== '' then rules = rules';'
         rules = rules || opener~translate closer~translate namePairs(def, names)
         end
   out~append('Within_rules'~left(15)"= '"rules"'")
   out~append('Mask_op'~left(15)"= '"op"'")
   return out

/* namePairs -- 'NAME min ...' for the named commands, with their
 * aliases, for matching the typed command with abbrev() */
::routine namePairs
   use strict arg def, names
   pairs = ''
   do name over names~space~makeArray(' ')
      do cmd over def['CMDS']
         if cmd['NAME'] \== name~translate then iterate
         pairs = pairs cmd['NAME'] cmd['MIN']
         do s over cmd['SYNONYMS']
            pairs = pairs s[1] s[2]
            end
         end
      end
   return pairs~strip

/* kwText -- template text as a Rexx expression; when the definition
 * has §case, wrapped in Kw() so that the macro applies the user's
 * keyword case at run time */
::routine kwText
   use strict arg def, text
   expr = rexxText(text)
   if def['CASE'] == .nil then return expr
   return 'Kw('expr')'

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
