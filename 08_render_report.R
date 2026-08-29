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

# --- render (PDF is the SAFE standard; the Rmd YAML also defines Word output) ---
rmarkdown::render(
  input         = "SAFE_snow_gmacs.Rmd",
  output_format = "bookdown::pdf_document2",
  envir         = new.env()
)
