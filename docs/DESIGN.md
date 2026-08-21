# Design notes

This rice follows a Sane Web / Unix-oriented interface language rather than a
"retro theme" or a rule that every application must look identical.

Practical rules used here:

- content and structure should stay recognizable;
- textual paths, labels and status are preferred over invented dashboard layers;
- chrome is coherent and restrained: Terminus, flat surfaces, thin straight
  borders, square controls, no compositor blur/shadow layer;
- color has a semantic job: focus, selection, urgency, boundary;
- light/dark are real appearance modes, not random outputs from wallpaper
  extraction;
- tiled/floating/monocle are functional layouts. Floating is available, but it
  is not treated as an aesthetic principle;
- application content is allowed to remain application content. Websites,
  images and PDFs are not globally recolored merely to match the shell.

The result should feel locally authored and simple without turning into fake
Plan 9, fake terminal UI, or deliberately impoverished software.
