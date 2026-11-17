/* assemble.rex
 *
 * Wraps the intro/gml/hlasm/rexx .tex fragments (written by
 * odt-to-latex-converter.rex) in the document preamble and section
 * headings, producing Prefix.Macros.tex. Plain text templating, no
 * JSON/XML involved -- ported to ooRexx alongside the converter for
 * the same reason (see odt-to-latex-converter.rex's own header).
 *
 * Usage: rexx assemble.rex
 *
 * Author: Claude Code, 2026-09-22
 */

call main
exit

::routine main
    preamble = "% Build: pandoc -f odt -t json Prefix.Macros.odt -o Prefix.Macros.json" || '0a'x || ,
               "%       rexx odt-to-latex-converter.rex Prefix.Macros.json" || '0a'x || ,
               "%       rexx assemble.rex" || '0a'x || ,
               "%       pdflatex Prefix.Macros.tex" || '0a'x || ,
               "%" || '0a'x || ,
               "% Converted from Prefix.Macros.odt by walking pandoc's own JSON AST" || '0a'x || ,
               "% (odt-to-latex-converter.rex) -- pandoc resolves the ODF's structure" || '0a'x || ,
               "% correctly, using a real parser; this script only decides this" || '0a'x || ,
               "% document's own grouping quirks and emits semantic markup (pfxmacros.sty)" || '0a'x || ,
               "% in place of raw \textbf/\textit/tabular." || '0a'x || ,
               '\documentclass[11pt]{article}' || '0a'x || ,
               '\usepackage[letterpaper,margin=1in]{geometry}' || '0a'x || ,
               '\usepackage{enumitem}' || '0a'x || ,
               '\usepackage{pfxmacros}' || '0a'x || ,
               '% Bold comes from \pfxcommand itself (pfxmacros.sty), not from here.' || '0a'x || ,
               '\setlist[description]{leftmargin=\pfxprefixwidth, labelsep=0.3cm, style=nextline, font=\normalfont}' || '0a'x || ,
               '0a'x || ,
               '\title{Prefix Macros for THE and XEDIT}' || '0a'x || ,
               '\author{Seymour J. Metz (H: Shmuel)}' || '0a'x || ,
               '\date{}' || '0a'x || ,
               '0a'x || ,
               '\begin{document}' || '0a'x || ,
               '\maketitle' || '0a'x || ,
               '0a'x

    intro = strip(readFile('intro.tex'))
    gml   = strip(readFile('gml.tex'))
    hlasm = strip(readFile('hlasm.tex'))
    rexxf = strip(readFile('rexx.tex'))

    doc = preamble || intro || '0a'x || '0a'x
    doc = doc || '\section*{Prefix macros for GML}' || '0a'x || '0a'x || gml || '0a'x || '0a'x
    doc = doc || '\section*{Prefix macros for High Level Assembler}' || '0a'x || '0a'x || hlasm || '0a'x || '0a'x
    doc = doc || '\section*{Prefix macros for REXX}' || '0a'x || '0a'x || rexxf || '0a'x || '0a'x
    doc = doc || '\end{document}' || '0a'x

    s = .stream~new('Prefix.Macros.tex')~~open('write replace')
    s~charout(doc)
    s~close
    say 'wrote' length(doc) 'bytes'
    return

::routine readFile
    use strict arg path
    s = .stream~new(path)~~open('read')
    text = s~charin(1, s~chars)
    s~close
    return text
