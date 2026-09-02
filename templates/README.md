# templates/

Build assets for the SAFE render. Not model input, not output.

## `reference_pagenumbers.docx`

A pandoc reference document whose only difference from pandoc's built-in default
is its default footer: the short document title ("EBS snow crab assessment,
September 2026") on the left, so reviewers can identify loose printed pages, and
a `PAGE` field on the right (title added at GA request, 2026-08-31; update the
title text in `word/footer1.xml` each cycle). The BSAI Crab SAFE Report Review
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
