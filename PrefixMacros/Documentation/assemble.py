PREAMBLE = r"""% Build: pandoc -f odt -t json Prefix.Macros.odt -o Prefix.Macros.json
%       python3 odt-to-latex-converter.py Prefix.Macros.json
%       python3 assemble.py
%       pdflatex Prefix.Macros.tex
%
% Converted from Prefix.Macros.odt by walking pandoc's own JSON AST
% (odt-to-latex-converter.py) -- pandoc resolves the ODF's structure
% correctly, using a real parser; this script only decides this
% document's own grouping quirks and emits semantic markup (pfxmacros.sty)
% in place of raw \textbf/\textit/tabular.
\documentclass[11pt]{article}
\usepackage[letterpaper,margin=1in]{geometry}
\usepackage{enumitem}
\usepackage{pfxmacros}
% Bold comes from \pfxcommand itself (pfxmacros.sty), not from here.
\setlist[description]{leftmargin=\pfxprefixwidth, labelsep=0.3cm, style=nextline, font=\normalfont}

\title{Prefix Macros for THE and XEDIT}
\author{Shmuel (Seymour J.) Metz}
\date{}

\begin{document}
\maketitle

"""

intro = open("intro.tex", encoding="utf-8").read().strip()
gml = open("gml.tex", encoding="utf-8").read().strip()
hlasm = open("hlasm.tex", encoding="utf-8").read().strip()
rexx = open("rexx.tex", encoding="utf-8").read().strip()

doc = PREAMBLE + intro + "\n\n"
doc += r"\section*{Prefix macros for GML}" + "\n\n" + gml + "\n\n"
doc += r"\section*{Prefix macros for High Level Assembler}" + "\n\n" + hlasm + "\n\n"
doc += r"\section*{Prefix macros for REXX}" + "\n\n" + rexx + "\n\n"
doc += r"\end{document}" + "\n"

open("Prefix.Macros.tex", "w", encoding="utf-8", newline="\n").write(doc)
print("wrote", len(doc), "bytes")
