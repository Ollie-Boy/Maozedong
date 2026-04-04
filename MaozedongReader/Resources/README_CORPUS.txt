Bundled poetry corpus format
=============================

The app reads UTF-8 text from:
- BundledPoetryCorpus.txt (optional), or
- BundledPoetryCorpus_part01.txt … part99.txt (concatenated in order)

At runtime it looks under the bundle’s Resources subfolder first, then the **bundle root** (Xcode’s default copy location).

Each work must start at the beginning of a line with:
  <序号> <标题>
Example:
  28 沁园春·长沙

The following lines are the body (date lines, poem text, 注释 blocks) until the next numbered title.

If the bundled file is missing or empty, the library still works with bundled anthology and imports.
