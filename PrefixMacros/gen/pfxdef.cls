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

