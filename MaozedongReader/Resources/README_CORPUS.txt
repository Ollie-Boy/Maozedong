Bundled poetry corpus format
=============================

The app reads UTF-8 text from:
- MaozedongReader/Resources/BundledPoetryCorpus.txt, or
- BundledPoetryCorpus_part01.txt … part99.txt (concatenated in order)

Each work must start at the beginning of a line with:
  <序号> <标题>
Example:
  28 沁园春·长沙

The following lines are the body (date lines, poem text, 注释 blocks) until the next numbered title.

If the bundled file is missing or empty, the library still works with samples and imports.
