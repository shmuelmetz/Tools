/* Developed with AI assistance from Claude Opus 5.5 (Anthropic) -- 17 Nov 2026 */
/* texexpand.rex
 *
 * Copy a LaTeX file with each line that is only \input{file} replaced
 * by that file's text, for pandoc: pandoc passes a list environment
 * holding an \input through as raw LaTeX, so the generated prefix-macro
 * documentation fragments would be missing from the ODT.  Paths in
 * \input are relative to the input file's folder; ".tex" is added when
 * the name has no extension.
 *
 * Usage:
 *   rexx texexpand.rex in.tex out.tex
 *
 * Exit code: 0 done, 1 usage, or an input file not found.
 *
 * Author: Seymour J. Metz (H: Shmuel)
 * Repo:   https://github.com/shmuelmetz/Personal
 */

parse arg inFile outFile .
if outFile = '' then do
   say 'Usage: rexx texexpand.rex in.tex out.tex'
   exit 1
   end
lines = readAll(inFile)
if lines == .nil then exit 1
folder = filespec('L', inFile~changeStr('/', '\'))

out = .array~new
do line over lines
   parse var line lead '\input{' name '}' rest
   if lead~strip \== '' | rest~strip \== '' | name == '' then do
      out~append(line)
      iterate
      end
   if name~lastPos('.') <= name~lastPos('/') then name = name'.tex'
   inc = readAll(folder || name~changeStr('/', '\'))
   if inc == .nil then exit 1
   do incLine over inc
      out~append(incLine)
      end
   end

s = .stream~new(outFile)
s~command('OPEN WRITE REPLACE')
do line over out
   s~lineOut(line)
   end
s~close
exit 0

::routine readAll
   use strict arg path
   if stream(path, 'C', 'QUERY EXISTS') = '' then do
      say 'texexpand:' path 'not found'
      return .nil
      end
   s = .stream~new(path)
   s~open('READ')
   lines = s~arrayIn
   s~close
   return lines
