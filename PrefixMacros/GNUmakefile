# GNUmakefile -- prefix macros for THE and XEDIT
#
# Targets:
#   pfx       generate the THE and XEDIT macros from src/*.src and lang/*.pfx
#             into out/, stamp the THE acknowledgements, and copy any macro
#             that changed into build/ (committed: the product)
#   check     regenerate and fail if build/ differs from what the sources give
#   docs      build the documentation (Documentation/): Prefix.Macros.pdf and
#             .odt, pfx.slides.pdf and .odp (not committed; go in the release)
#   release   zip the macros, the setup files and the documentation into
#             out/PrefixMacros-<version>.zip, for a GitHub release
#   export    copy the published files into the web site's sample-code
#             section: $(PERSONAL_WEB)/source and $(PERSONAL_WEB)/Documentation
#             (set PERSONAL_WEB to the web site's local root)
#   clean     remove LaTeX auxiliary files and out/
#
# Requirements: ooRexx (rexx), and for docs XeLaTeX, pandoc 3.x and
# LibreOffice (soffice); zip for release.
#
# Run from this directory (tools/PrefixMacros).

REXX      ?= rexx
SOFFICE   ?= soffice
# LANGS: the language definitions (lang/<lang>.pfx) or sources
# (src/pfx<lang>.src) to generate from; MACROS: the macros they give
# (a definition's :macro.; both GML definitions share src/pfxgml.src).
# CREDITED: the THE macros that carry the acknowledgements in
# pfx-credits.txt: all of them, since the GML source reuses the THE
# compatibility fixes made for PFXREXX and PFXHLASM.
LANGS     := rexx hlasm gml dcfgml
MACROS    := pfxrexx pfxhlasm pfxgmlw pfxgmlss
CREDITED  := $(MACROS)
upper      = $(shell echo $(1) | tr a-z A-Z)

OUT_THE   := $(foreach m,$(MACROS),out/the/$(m).the)
OUT_XEDIT := $(foreach m,$(MACROS),out/xedit/$(call upper,$(m)).XEDIT)
BUILD     := $(foreach m,$(MACROS),build/the/$(m).the build/xedit/$(call upper,$(m)).XEDIT)

DOC_DIR   := Documentation
DOCS      := $(DOC_DIR)/Prefix.Macros.pdf $(DOC_DIR)/Prefix.Macros.odt \
             $(DOC_DIR)/pfx.slides.pdf $(DOC_DIR)/pfx.slides.odp
SETUP     := setup/PROFILE.THE setup/pfx.the

.PHONY: all pfx generate check docs release export clean
all: pfx

# out/: the generated macros and documentation fragments
generate:
	$(REXX) gen/pfxgen.rex $(LANGS)
	$(REXX) gen/pfxdoc.rex
	$(REXX) gen/stamp-pfx-credits.rex pfx-credits.txt $(foreach m,$(CREDITED),out/the/$(m).the)

pfx: generate
	@for f in $(OUT_THE) $(OUT_XEDIT); do \
	    t=build/$$(basename $$(dirname $$f))/$$(basename $$f); \
	    cmp -s $$f $$t || { mkdir -p $$(dirname $$t); cp $$f $$t; echo "updated $$t"; }; \
	done

check: generate
	@status=0; for f in $(OUT_THE) $(OUT_XEDIT); do \
	    t=build/$$(basename $$(dirname $$f))/$$(basename $$f); \
	    cmp -s $$f $$t || { echo "OUT OF DATE: $$t (run make pfx)"; status=1; }; \
	done; \
	[ $$status = 0 ] && echo "build/ matches the sources"; exit $$status

# ---------------------------------------------------------------------------
# Documentation. The LaTeX files are the sources. The PDFs come from
# XeLaTeX; the LibreOffice files come from pandoc reading the same LaTeX:
#   - pfxmacros.lua gives pandoc the pfxmacros.sty markup; the template
#     tables take pfx-reference.odt's monospaced "Table Contents" style;
#     odt-cell-borders.lua then gives the cells borders.
#   - pfx-slides.lua turns the beamer frames into slides; pandoc writes
#     pptx (with pfx-reference.pptx) and LibreOffice converts it to ODP.
#   - The REXX template entries come from out/doc/pfx-rexx.tex, written
#     by gen/pfxdoc.rex from lang/rexx.pfx. pandoc does not follow an
#     \input inside a list, so for the ODT the fragments are expanded
#     into a temporary copy first (gen/texexpand.rex).
#   - Citations come from Documentation/pfxrefs.bib: BibTeX (plainurl)
#     for the PDF, run only for a document that has \bibliography;
#     pandoc --citeproc for the ODT.
# (tex4ht/make4ht would build the ODT directly, but it does not write ODP.)
# ---------------------------------------------------------------------------

docs: generate $(DOCS)

PFX_DOC := $(wildcard out/doc/pfx-*.tex)

$(DOC_DIR)/%.pdf: $(DOC_DIR)/%.tex $(DOC_DIR)/pfxmacros.sty $(DOC_DIR)/pfxrefs.bib $(PFX_DOC)
	cd $(DOC_DIR) && xelatex -interaction=nonstopmode $*.tex
	cd $(DOC_DIR) && if grep -q -F '\bibliography{' $*.tex; then bibtex $*; fi
	cd $(DOC_DIR) && xelatex -interaction=nonstopmode $*.tex
	cd $(DOC_DIR) && xelatex -interaction=nonstopmode $*.tex

$(DOC_DIR)/Prefix.Macros.odt: $(DOC_DIR)/Prefix.Macros.tex $(DOC_DIR)/pfxmacros.lua \
                              $(DOC_DIR)/pfx-reference.odt $(DOC_DIR)/odt-cell-borders.lua \
                              $(DOC_DIR)/pfxrefs.bib $(PFX_DOC) gen/texexpand.rex
	$(REXX) gen/texexpand.rex $(DOC_DIR)/Prefix.Macros.tex $(DOC_DIR)/Prefix.Macros.expanded.tex
	cd $(DOC_DIR) && pandoc -f latex+raw_tex --lua-filter=pfxmacros.lua \
	    --citeproc -M reference-section-title=References \
	    --reference-doc=pfx-reference.odt -s Prefix.Macros.expanded.tex -o Prefix.Macros.odt
	cd $(DOC_DIR) && pandoc lua odt-cell-borders.lua Prefix.Macros.odt
	$(RM) $(DOC_DIR)/Prefix.Macros.expanded.tex

$(DOC_DIR)/pfx.slides.odp: $(DOC_DIR)/pfx.slides.tex $(DOC_DIR)/pfx-slides.lua \
                           $(DOC_DIR)/pfx-reference.pptx
	cd $(DOC_DIR) && pandoc -f latex -t pptx --lua-filter=pfx-slides.lua \
	    --reference-doc=pfx-reference.pptx -s pfx.slides.tex -o pfx.slides.pptx
	cd $(DOC_DIR) && $(SOFFICE) --headless --convert-to odp pfx.slides.pptx
	$(RM) $(DOC_DIR)/pfx.slides.pptx

# ---------------------------------------------------------------------------
# Packaging and publishing
# ---------------------------------------------------------------------------

# Release tags are PrefixMacros-<version> (the tools repository holds
# other tools too); only the PrefixMacros tags are considered, and the
# zip is named PrefixMacros-<version>.zip.
VERSION := $(patsubst PrefixMacros-%,%,$(shell git describe --tags --match 'PrefixMacros-*' --always 2>/dev/null))

release: check docs
	$(RM) out/PrefixMacros-$(VERSION).zip
	zip -j -q out/PrefixMacros-$(VERSION).zip $(BUILD) $(SETUP) $(DOCS) pfx-credits.txt
	@echo "wrote out/PrefixMacros-$(VERSION).zip; attach it to the GitHub release PrefixMacros-$(VERSION)"

export: check
	@[ -n "$(PERSONAL_WEB)" ] || { echo "set PERSONAL_WEB to the web site's local root"; exit 1; }
	@for f in $(BUILD) $(SETUP); do \
	    t=$(PERSONAL_WEB)/source/$$(basename $$f); \
	    cmp -s $$f $$t || { cp $$f $$t; echo "updated $$t"; }; \
	done
	@for f in $(DOC_DIR)/Prefix.Macros.pdf $(DOC_DIR)/Prefix.Macros.odt $(DOC_DIR)/pfx.slides.pdf; do \
	    [ -f $$f ] || continue; \
	    t=$(PERSONAL_WEB)/Documentation/$$(basename $$f); \
	    cmp -s $$f $$t || { cp $$f $$t; echo "updated $$t"; }; \
	done

AUX_EXTS := aux log out toc lof lot fls fdb_latexmk synctex.gz synctex \
            pdfsync blg bbl bcf run.xml nav snm vrb idx ind ilg

clean:
	$(foreach ext,$(AUX_EXTS),$(RM) $(wildcard $(DOC_DIR)/*.$(ext)))
	$(RM) -r out
