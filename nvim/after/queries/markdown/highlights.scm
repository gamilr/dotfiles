;; extends

; Neovim's LSP hover float (`K`) sets 'conceallevel' to 2 and highlights the
; buffer with the `markdown` parser, but the bundled markdown/highlights.scm
; only conceals code-fence delimiters -- ATX heading markers are left as-is,
; so clangd hovers show a literal `### foo` instead of a rendered heading.
; Conceal the markers here; this only takes effect in windows that enabled
; 'conceallevel' (the LSP float, and markdown buffers when conceal is toggled).
;
; Each marker collapses to a single ">"; the heading level itself is carried
; by the @markup.heading.N highlight (colour + bold). Conceal takes exactly
; one character -- swap in "#", "▎", "" (hide it entirely), or the
; nerd-font level badges 󰲡 󰲣 󰲥 󰲧 󰲩 󰲫 if you want the level spelled out.

((atx_h1_marker) @markup.heading.1.marker
  (#set! conceal ">"))

((atx_h2_marker) @markup.heading.2.marker
  (#set! conceal ">"))

((atx_h3_marker) @markup.heading.3.marker
  (#set! conceal ">"))

((atx_h4_marker) @markup.heading.4.marker
  (#set! conceal ">"))

((atx_h5_marker) @markup.heading.5.marker
  (#set! conceal ">"))

((atx_h6_marker) @markup.heading.6.marker
  (#set! conceal ">"))
