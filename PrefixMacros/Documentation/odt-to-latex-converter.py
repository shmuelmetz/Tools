#!/usr/bin/env python3
"""One-off converter: Prefix.Macros.odt's content.xml -> the four LaTeX
body fragments (intro/gml/hlasm/rexx) assembled into Prefix.Macros.tex.

Not a general ODF-to-LaTeX tool -- it's shaped around this document's own
structure: a flat description-list per section (GML), and per-command
entries (HLASM, REXX) that pair a name with a "prefix area / text area"
example table, expressed inconsistently across the source (sometimes
nested in the list item, sometimes as sibling paragraphs/tables). Kept
here for provenance and as a starting point if pfx.slides.odt or a
similar document is ever converted the same way.

Usage: unzip content.xml from the .odt into this directory, then
  python3 odt-to-latex-converter.py
which writes intro.tex, gml.tex, hlasm.tex, rexx.tex and, via the
adjoining assemble step, Prefix.Macros.tex.

Author: Claude Code, 2026-09-22
"""
import re, html

LIST_OPEN = re.compile(r'<text:list(?=[ >])')

xml = open("content.xml", encoding="utf-8").read()
i = xml.find("<office:body>")
body = xml[i:xml.find("</office:body>")+len("</office:body>")]
m = re.search(r'<office:text[^>]*>(.*)</office:text>', body, re.S)
inner = m.group(1)
inner = re.sub(r'<text:sequence-decls>.*?</text:sequence-decls>', '', inner, flags=re.S)

SPECIALS = [
    ('\\', r'\textbackslash{}'),
    ('&', r'\&'),
    ('%', r'\%'),
    ('$', r'\$'),
    ('#', r'\#'),
    ('_', r'\_'),
    ('{', r'\{'),
    ('}', r'\}'),
    ('~', r'\textasciitilde{}'),
    ('^', r'\textasciicircum{}'),
    # A raw "|" in OT1-encoded Computer Modern does not reliably render
    # as a plain vertical bar; \textbar{} does.
    ('|', r'\textbar{}'),
]

def esc(s):
    s = html.unescape(s)
    for a, b in SPECIALS:
        s = s.replace(a, b)
    return s

def inline(s):
    out = []
    pos = 0
    pat = re.compile(r'<text:span text:style-name="(T\d+)">(.*?)</text:span>|<text:tab/>|<text:s(?:\s+text:c="(\d+)")?/>')
    for m in pat.finditer(s):
        plain = re.sub('<[^>]+>', '', s[pos:m.start()])
        out.append(esc(plain))
        whole = m.group(0)
        if m.group(1) is not None:
            style, txt = m.group(1), m.group(2)
            txt = esc(re.sub('<[^>]+>', '', txt))
            if style == 'T1':
                out.append(r'\textbf{%s}' % txt)
            elif style in ('T4', 'T5'):
                out.append(r'\textit{%s}' % txt)
            else:
                out.append(txt)
        elif whole.startswith('<text:tab'):
            out.append(r'\hspace{1em}')
        else:
            n = int(m.group(3) or 1)
            out.append(r'\ ' * n)
        pos = m.end()
    out.append(esc(re.sub('<[^>]+>', '', s[pos:])))
    result = ''.join(out).strip()
    result = result.replace(r'\textbf{}', '').replace(r'\textit{}', '')
    return result

def parse_p(p_xml):
    m = re.match(r'<text:p[^>]*>(.*)</text:p>', p_xml, re.S)
    return inline(m.group(1)) if m else ''

def parse_table(t_xml):
    rows = re.findall(r'<table:table-row\b.*?</table:table-row>', t_xml, re.S)
    out = [r'\begin{tabular}{@{}p{2.2cm}p{9.5cm}@{}}', r'\hline']
    for r in rows:
        cells = re.findall(r'<table:table-cell\b.*?</table:table-cell>', r, re.S)
        texts = []
        for c in cells:
            ps = re.findall(r'<text:p[^>]*>.*?</text:p>', c, re.S)
            texts.append(' '.join(parse_p(p) for p in ps))
        while len(texts) < 2:
            texts.append('')
        out.append('%s & %s \\\\' % (texts[0], texts[1]))
        out.append(r'\hline')
    out.append(r'\end{tabular}')
    return '\n'.join(out)

def tokenize(xml_frag):
    tokens = []
    pos = 0
    n = len(xml_frag)
    while pos < n:
        m = re.match(r'\s*', xml_frag[pos:])
        pos += m.end()
        if pos >= n:
            break
        if xml_frag[pos:pos+7] == '<text:p':
            close_self = re.match(r'<text:p[^>]*/>', xml_frag[pos:])
            if close_self:
                tokens.append(('p', close_self.group(0)))
                pos += close_self.end()
                continue
            end = xml_frag.index('</text:p>', pos) + len('</text:p>')
            tokens.append(('p', xml_frag[pos:end]))
            pos = end
        elif LIST_OPEN.match(xml_frag, pos):
            depth = 0
            j = pos
            while True:
                mno = LIST_OPEN.search(xml_frag, j)
                no = mno.start() if mno else -1
                nc = xml_frag.find('</text:list>', j)
                if no != -1 and no < nc:
                    depth += 1
                    j = xml_frag.index('>', no) + 1
                else:
                    depth -= 1
                    j = nc + len('</text:list>')
                    if depth == 0:
                        break
            tokens.append(('list', xml_frag[pos:j]))
            pos = j
        elif xml_frag[pos:pos+12] == '<table:table':
            end = xml_frag.index('</table:table>', pos) + len('</table:table>')
            tokens.append(('table', xml_frag[pos:end]))
            pos = end
        else:
            end = xml_frag.index('>', pos) + 1
            pos = end
    return tokens

def list_items(list_xml):
    inner = re.sub(r'^<text:list[^>]*>', '', list_xml)
    inner = re.sub(r'</text:list>$', '', inner)
    items = []
    pos = 0
    n = len(inner)
    while pos < n:
        s = inner.find('<text:list-item', pos)
        if s == -1:
            break
        depth = 0
        j = s
        while True:
            no = inner.find('<text:list-item', j)
            nc = inner.find('</text:list-item>', j)
            if no != -1 and no < nc:
                depth += 1
                j = inner.index('>', no) + 1
            else:
                depth -= 1
                j = nc + len('</text:list-item>')
                if depth == 0:
                    break
        items.append(inner[s:j])
        pos = j
    return items

def parse_item(item_xml):
    inner = re.sub(r'^<text:list-item[^>]*>', '', item_xml)
    inner = re.sub(r'</text:list-item>$', '', inner)
    toks = tokenize(inner)
    paras = []
    nested = None
    for kind, x in toks:
        if kind == 'p':
            paras.append(parse_p(x))
        elif kind == 'list':
            nested = x
    return paras, nested

body_tokens = tokenize(inner)
print(len(body_tokens), "top-level tokens")
for k, x in body_tokens[:10]:
    print(k, x[:90].replace('\n', ' '))

# ---- Full document generation ----

def render_item_body(paras, nested):
    """Render the description-list body for one item: joined paragraphs,
    plus a nested itemize if present."""
    parts = []
    text = ' '.join(p for p in paras if p).strip()
    if text:
        parts.append(text)
    if nested is not None:
        sub_items = list_items(nested)
        lines = [r'\begin{itemize}']
        for si in sub_items:
            sp, snested = parse_item(si)
            label = sp[0] if sp else ''
            boldlabel = label if r'\textbf{' in label else r'\textbf{%s}' % label
            body = ' '.join(sp[1:]).strip()
            lines.append(r'\item %s%s' % (boldlabel, (': ' + body) if body else ''))
        lines.append(r'\end{itemize}')
        parts.append('\n'.join(lines))
    return '\n'.join(parts)

def strip_leading_hspace(s):
    return re.sub(r'^(\\hspace\{1em\})+', '', s).strip()

def render_section(tokens):
    out = []
    in_desc = [False]
    pending = []  # body pieces (str) for the currently-open \item

    def open_desc():
        if not in_desc[0]:
            out.append(r'\begin{description}')
            in_desc[0] = True

    def flush_item(boldlabel):
        parts = [p for p in pending if p]
        # The first piece (the description sentence, if any) runs inline
        # right after the label, matching the two-column look. Anything
        # after that -- an example table, a nested itemize -- gets its
        # own paragraph (a blank line): `tabular` does not force a line
        # break on its own, and without one it embeds inline after the
        # description text and visually fragments across line wraps.
        if parts:
            body = parts[0] + ''.join('\n\n' + p for p in parts[1:])
        else:
            body = ''
        out.append(r'\item[{%s}] %s' % (boldlabel, body))
        pending.clear()

    current_label = [None]

    def close_pending():
        if current_label[0] is not None:
            flush_item(current_label[0])
            current_label[0] = None

    def close_desc():
        close_pending()
        if in_desc[0]:
            out.append(r'\end{description}')
            in_desc[0] = False

    for k, x in tokens:
        if k == 'p':
            txt = parse_p(x) if '</text:p>' in x else ''
            if not txt:
                continue
            is_transition = ('GLOBALV' in txt and 'indentation' in txt) or \
                'The prefix commands for' in txt or 'Prefix macros for' in txt
            if current_label[0] is not None and not is_transition:
                # a continuation paragraph belonging to the open item.
                # Most are tab-indented in the source; one (the "nnRI"
                # description) is not, an authoring slip -- so section
                # transitions are identified positively by their fixed
                # wording instead of by the tab's presence.
                pending.append(strip_leading_hspace(txt))
            else:
                close_desc()
                out.append(txt)
                out.append('')
        elif k == 'list':
            items = list_items(x)
            # Drop a leading item whose label is pure whitespace/empty: a
            # spurious blank bullet in the source (e.g. before "DO FR"),
            # not a real entry.
            while items:
                p0chk, _ = parse_item(items[0])
                if p0chk and p0chk[0].strip():
                    break
                items = items[1:]
            if not items:
                continue
            open_desc()
            close_pending()
            # A 2-item list whose second item reads like a description
            # ("Insert ...") is really one command's name + description
            # split across two bullets (e.g. "CASEE or CASEN").
            if len(items) == 2:
                p0, n0 = parse_item(items[0])
                p1, n1 = parse_item(items[1])
                lbl1 = p1[0] if p1 else ''
                if lbl1.startswith('Insert ') or lbl1.startswith('\\textbf{Insert '):
                    label = p0[0] if p0 else ''
                    current_label[0] = label if r'\textbf{' in label else r'\textbf{%s}' % label
                    pending.append(' '.join([lbl1] + p1[1:]).strip())
                    if n0 is not None:
                        pending.append(render_item_body([], n0))
                    continue
            # Every item except the last is self-contained and flushed
            # immediately; the last item stays open so a following
            # description paragraph and/or example table (siblings in
            # the source, not nested in the list) can attach to it.
            for it in items[:-1]:
                paras, nested = parse_item(it)
                label = paras[0] if paras else ''
                boldlabel = label if r'\textbf{' in label else r'\textbf{%s}' % label
                own_body = render_item_body(paras[1:], nested)
                out.append(r'\item[{%s}] %s' % (boldlabel, own_body))
            paras, nested = parse_item(items[-1])
            label = paras[0] if paras else ''
            current_label[0] = label if r'\textbf{' in label else r'\textbf{%s}' % label
            own_body = render_item_body(paras[1:], nested)
            if own_body:
                pending.append(own_body)
        elif k == 'table':
            if current_label[0] is None:
                # Defensive: a table with no open item to attach to would
                # otherwise sit in `pending` and leak into whatever item
                # opens next. Should not happen once source anomalies
                # (e.g. a spurious blank bullet) are filtered above.
                pending.clear()
            pending.append(parse_table(x))
    close_desc()
    return '\n'.join(out)

# Split body_tokens into the three named sections by locating the
# section-introduction paragraphs (identified by their exact text).
body_tokens = tokenize(inner)

def find_marker(tokens, substr):
    for i, (k, x) in enumerate(tokens):
        if k == 'p' and '</text:p>' in x and substr in parse_p(x):
            return i
    return None

i_gml = find_marker(body_tokens, 'The prefix commands for GML are:')
i_hlasm = find_marker(body_tokens, 'Prefix macros for High Level Assembler:')
i_rexx = find_marker(body_tokens, 'Prefix macros for REXX:')

intro_tokens = body_tokens[:i_gml]
gml_tokens = body_tokens[i_gml+1:i_hlasm]
hlasm_tokens = body_tokens[i_hlasm+1:i_rexx]
rexx_tokens = body_tokens[i_rexx+1:]

intro_body = render_section(intro_tokens)
gml_body = render_section(gml_tokens)
hlasm_body = render_section(hlasm_tokens)
rexx_body = render_section(rexx_tokens)

open("intro.tex", "w", encoding="utf-8").write(intro_body)
open("gml.tex", "w", encoding="utf-8").write(gml_body)
open("hlasm.tex", "w", encoding="utf-8").write(hlasm_body)
open("rexx.tex", "w", encoding="utf-8").write(rexx_body)
print("wrote intro/gml/hlasm/rexx .tex fragments")
print("gml body length:", len(gml_body))
print("hlasm body length:", len(hlasm_body))
print("rexx body length:", len(rexx_body))
