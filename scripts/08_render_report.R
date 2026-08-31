# Render the September 2026 SAFE report.
# Verified working invocation (R 4.5.1). pandoc is not on PATH from a plain terminal, so we point
# rmarkdown at the pandoc bundled with Positron. Run from the snow_sept repo root:
#   & "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe" 08_render_report.R
# (Rendering from inside Positron/RStudio works without the RSTUDIO_PANDOC line, since the IDE
#  sets it automatically.)

# --- locate pandoc (system PATH -> Positron bundle -> error) ---
# The assessment moved to macOS in August 2026 (docs/MACOS_GMACS.md), where pandoc
# is on PATH from Homebrew and rmarkdown finds it unaided. The Positron lookup
# below is the Windows fallback and is only consulted if PATH does not have it.
if (!rmarkdown::pandoc_available()) {
  candidate <- file.path(Sys.getenv("LOCALAPPDATA"),
                         "Programs/Positron/resources/app/quarto/bin/tools")
  if (file.exists(file.path(candidate, "pandoc.exe"))) {
    Sys.setenv(RSTUDIO_PANDOC = candidate)
  }
}
stopifnot("pandoc not found - open in Positron or set RSTUDIO_PANDOC" = rmarkdown::pandoc_available())
cat("Using pandoc", as.character(rmarkdown::pandoc_version()),
    "from", if (nzchar(Sys.getenv("RSTUDIO_PANDOC"))) Sys.getenv("RSTUDIO_PANDOC")
            else dirname(Sys.which("pandoc")), "\n")

# --- LaTeX passes --------------------------------------------------------------
# Force at least three. The table of contents is two pages long, so inserting it
# pushes every numbered page down by two; the .toc written on the pass before
# still holds the old numbers, and LaTeX does NOT emit "Rerun to get
# cross-references right" for a stale .toc (that warning covers \label/\ref
# only). tinytex therefore stopped early and shipped a contents list that was
# uniformly two pages out -- "Executive Summary 2" against a printed folio of 4,
# "Tables 55" against 57 (found 2026-08-29, on the third reviewer pass).
# min_times defaults to 1; max_times is already 10, so this only raises the floor.
options(tinytex.compile.min_times = 3)

# --- which output? -------------------------------------------------------------
# PDF is the SAFE standard and stays the default. Word is for circulating the
# draft to co-authors for tracked-changes review:
#   Rscript 08_render_report.R          -> 2026_snowcrab_safe_draft.pdf
#   Rscript 08_render_report.R docx     -> 2026_snowcrab_safe_draft.docx
#   Rscript 08_render_report.R both
#
# The Word path goes through officedown::rdocx_document (see the Rmd YAML) so the
# table and figure captions carry SEQ fields that \@ref() can target, and so the
# page-number footer in templates/reference_pagenumbers.docx is picked up.
# NOTE the List of Tables and List of Figures are Word TOC FIELDS: they render
# empty until Word computes them, which happens on open, on print preview, or on
# Ctrl+A then F9. That is Word behaviour, not a render failure.
.args <- commandArgs(trailingOnly = TRUE)
WHICH <- if (length(.args) && nzchar(.args[1])) tolower(.args[1]) else "pdf"
stopifnot("first argument must be pdf, docx or both" = WHICH %in% c("pdf", "docx", "both"))

if (WHICH %in% c("pdf", "both")) {
  cat("\n--- rendering PDF ---\n")
  rmarkdown::render(
    input         = "2026_snowcrab_safe_draft.Rmd",
    output_format = "bookdown::pdf_document2",
    envir         = new.env()
  )
}

# --- Word bookmark repair ------------------------------------------------------
# Word bookmark names may contain only letters, digits and underscores. Every
# table and figure label in this document is hyphenated, because the PDF path
# requires it: bookdown writes the label into the caption as (\#fig:name), and an
# underscore there is a LaTeX math character that kills the PDF build (verified
# again 2026-08-30). So the two formats want opposite things.
#
# Word silently DISCARDS a bookmark whose name is invalid, which leaves every
# cross-reference showing "Error! Reference source not found." -- reported from a
# real review copy, and the reason this exists. The PDF numbering is unaffected
# and stays as it is.
#
# Fix the .docx after the fact rather than the source: rename only those bookmarks
# that a REF field actually targets, and rewrite the matching field instructions.
# Heading bookmarks are LEFT ALONE -- the table of contents reaches them through
# hyperlink anchors, not REF fields, and renaming them would break the TOC.
repair_docx_bookmarks <- function(path) {
  stopifnot("docx not found" = file.exists(path))
  tmp <- file.path(tempdir(), "docx_repair")
  unlink(tmp, recursive = TRUE); dir.create(tmp, recursive = TRUE)
  files <- utils::unzip(path, exdir = tmp)
  doc <- file.path(tmp, "word", "document.xml")
  if (!file.exists(doc)) { warning("no word/document.xml; bookmarks not repaired"); return(invisible(FALSE)) }
  xml <- readChar(doc, file.size(doc), useBytes = TRUE)

  ## Which bookmarks are actually cross-referenced?
  targets <- unique(unlist(regmatches(xml, gregexpr("REF[[:space:]]+[A-Za-z0-9_:.-]+", xml))))
  targets <- unique(sub("^REF[[:space:]]+", "", targets))
  targets <- targets[grepl("-", targets)]           # only the ones Word will reject
  if (!length(targets)) { cat("  no hyphenated cross-references; nothing to repair\n"); return(invisible(FALSE)) }

  ## LONGEST FIRST. Label names nest -- "bsfrf-sel" is a prefix of
  ## "bsfrf-sel-all" -- so replacing the short one first rewrites the start of the
  ## long one and leaves a half-renamed target that matches no bookmark. Four
  ## references broke that way on the first run (2026-08-30).
  targets <- targets[order(nchar(targets), decreasing = TRUE)]

  for (t in targets) {
    safe <- gsub("-", "_", t)
    xml <- gsub(paste0("w:name=\"", t, "\""), paste0("w:name=\"", safe, "\""), xml, fixed = TRUE)
    xml <- gsub(paste0("REF ", t), paste0("REF ", safe), xml, fixed = TRUE)
  }
  ## Every cross-reference must now point at a bookmark that exists.
  .refs <- unique(sub("^REF[[:space:]]+", "",
                      unlist(regmatches(xml, gregexpr("REF[[:space:]]+[A-Za-z0-9_:.-]+", xml)))))
  .names <- unique(unlist(regmatches(xml, gregexpr('(?<=w:name=")[^"]+', xml, perl = TRUE))))
  .orphan <- setdiff(.refs, .names)
  stopifnot("docx repair left cross-references with no bookmark" = length(.orphan) == 0)

  writeChar(xml, doc, eos = NULL, useBytes = TRUE)

  ## Rezip from inside the extraction dir so the archive keeps its relative paths.
  owd <- setwd(tmp); on.exit(setwd(owd), add = TRUE)
  out <- file.path(owd, basename(path))
  unlink(out)
  utils::zip(out, list.files(".", recursive = TRUE, all.files = TRUE), flags = "-q -X")
  setwd(owd)
  cat(sprintf("  repaired %d cross-referenced bookmark(s) for Word\n", length(targets)))
  invisible(TRUE)
}

if (WHICH %in% c("docx", "both")) {
  cat("\n--- rendering Word ---\n")
  rmarkdown::render(
    input         = "2026_snowcrab_safe_draft.Rmd",
    output_format = "officedown::rdocx_document",
    output_file   = "2026_snowcrab_safe_draft.docx",
    envir         = new.env()
  )
  repair_docx_bookmarks("2026_snowcrab_safe_draft.docx")
}
