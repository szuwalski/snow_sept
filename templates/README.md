# templates/

Build assets for the SAFE render. Not model input, not output.

## `reference_pagenumbers.docx`

A pandoc reference document whose only difference from pandoc's built-in default
is a centred `PAGE` field in the default footer. The BSAI Crab SAFE Report Review
Checklist requires page numbers on every page; pandoc's default reference.docx
carries no footer part at all, so Word output had none. The PDF output numbers
pages through LaTeX and never needed this.

Rebuild it, if pandoc's default ever changes, with:

    pandoc --print-default-data-file reference.docx > ref.docx

then add `word/footer1.xml` (a `w:ftr` holding a `PAGE` field), declare it in
`[Content_Types].xml`, add a footer relationship in
`word/_rels/document.xml.rels`, and reference it from `w:sectPr` in
`word/document.xml` -- `w:footerReference` must precede `w:footnotePr`, which is
the order the OOXML schema requires.
