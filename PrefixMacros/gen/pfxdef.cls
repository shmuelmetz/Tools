/* Developed with AI assistance from Claude Opus 5.5 (Anthropic) -- 17 Nov 2026 */
/* pfxdef.cls -- shared by pfxgen.rex and pfxdoc.rex: read and check a
 * prefix-macro language definition (lang\<lang>.pfx).  See
 * pfxdoc.rex for the format.
 *
 * Author: Seymour J. Metz (H: Shmuel)
 * Repo:   https://github.com/shmuelmetz/Personal
 */

/* readDefinition -- a Directory: UNIT (Directory name->columns),
 * CMDS (Array of Directories: NAME MIN DESC FIRST CURSOR VARS ROWS),
 * plus every other top-level tag's value; .nil if unreadable */
::routine readDefinition public
   use strict arg path
   knownTags = 'LANG MACRO UNIT MASK COMMENT CONTINUE BLANK LABEL OPENS' ,
               'NESTED DEDENT CMD MIN DESC FIRST CURSOR VAR ROW LEVEL' ,
               'BUILTIN SYNONYM DISPATCH INSERT SOURCE ALIAS LINECOMMENT ANCHOR CASE MARGINS' ,
               'BEFORE WITHIN CLOSES'
   /* the tag marker: the section sign, U+00A7, in UTF-8; it occurs in
      none of the languages, so every one starts a tag and a value may
      hold any text (GML ":ROW.", ooRexx "::class") */
   marker = 'C2A7'x
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
      /* split into "tag value" pairs at each marker */
      if line~strip~left(marker~length) \== marker then do
         say 'pfxdef:' path': line does not start with a tag:' line
         return .nil
         end
      pairs = .array~new
      pieces = line~makeArray(marker)
      do piece over pieces
         if piece~strip == '' then iterate
         parse var piece tag value
         if knownTags~wordPos(tag~translate) = 0 then do
            say 'pfxdef:' path': unknown tag' tag
            return .nil
            end
         /* no stray carriage return, tab or line feed in a value (a
            CR CR LF line end once put a CR into a macro name) */
         value = value~translate('   ', '0D090A'x)~strip
         pairs~append(.array~of(tag~translate, value))
         end
      first = pairs[1]
      select
         when cmd \== .nil & first[1] == 'LEVEL' then
            cmd['LEVEL'] = first[2]
         when cmd \== .nil & first[1] == 'ALIAS' then do
            /* other names for the command, each with its minimum
               abbreviation (default: the whole name), e.g. STRTSRCH 5
               for SEARCH; matched with abbrev() like the command */
            words = first[2]~space~makeArray(' ')
            i = 1
            do while i <= words~items
               alias = words[i]~translate
               amin  = alias~length
               if i < words~items then
                  if datatype(words[i + 1], 'W') then do
                     amin = words[i + 1]
                     i = i + 1
                     end
               cmd['SYNONYMS']~append(.array~of(alias, amin))
               i = i + 1
               end
            end
         when first[1] == 'WITHIN' then do
            /* sanity checks: any number of §within lines */
            if \def~hasIndex('WITHINS') then def['WITHINS'] = .array~new
            def['WITHINS']~append(first[2])
            end
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
            cmd['SYNONYMS'] = .array~new
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
            /* an operand: - (none), * (any other), # (a number), a
               keyword and its minimum, or (a list of values) */
            if first[2]~left(1) == '(' then do
               parse value first[2] with '(' list ')' .
               var['OPERAND'] = '('list~space')'
               var['MIN'] = ''
               end
            else
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
::routine checkDefinition public
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

