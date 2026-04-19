# Neovim Snippet System — Session Handoff Context

**Version:** 1.0.0
**Purpose:** Full context for an incoming AI instance to continue building the
snippet and boilerplate system for a highly customized Neovim configuration.
Read this entire document before touching any file.

---

## WHO YOU ARE WORKING WITH

The operator is an experienced systems programmer building EigenState, a VCS
written in C99 with no stdlib, raw Linux syscalls, and a strict compile-time
enforcement framework. They write large amounts of C by hand following a rigid
style convention. The goal of this session is to build a Neovim snippet system
that eliminates repetitive boilerplate typing.

Critical working style notes:

- Operator is QC. They will catch errors. Do not assert things you are not
  certain of.
- One file at a time. Confirm before moving to the next.
- Never flag issues only in chat. Flag them in the file as comments too.
- Do not one-shot large amounts of work. Slow, verified, step by step.
- Plain text output for all code — operator copy-pastes, does not download.
- If you make an error, own it and fix it. Do not be defensive.
- The operator will patch files themselves if small fixes are needed and will
  tell you they did so. Do not regenerate patched files.

---

## THE KEYBOARD LAYOUT

The operator uses a Bastard Keyboards Skeletyl v2 (36-key split columnar)
running a custom Miryoku-derived QMK layout. This matters for keybind design.

- Leader = Space
- Ctrl = home row hold — ergonomically costly for rapid sequences
- Alt = home row hold — also costly
- j/k/l/; = movement (left/down/up/right) in normal mode
- Tab = smart indent in insert mode (taken)
- jj = Escape in insert mode
- Vulkan mode (dk) = capitalises all letters, spaces become underscores
- Contract mode (fk) = capitalises all letters, spaces preserved, auto-exits
  on ) or ;

---

## THE STYLE CONVENTION (AUTHORITATIVE)

The operator writes C, C++, headers, Fortran, Makefiles, and Markdown following
a strict style. The two authoritative documents are:

- naming_and_code_form_conventions.md
- code_taste_and_functional_form.md (current version is v0.3.0)

Key rules an incoming AI must know without reading those docs:

**Line length:** 95 soft, 100 hard. All comment borders fill to exactly 100
characters.

**Three-tier comment hierarchy:**

Tier 1 — File header. Opens every file. Uses * border characters.
```c
/* ****...****   (100 chars total)
 *
 *  filename.h
 *
 *  System — Subsystem
 *  Brief description.
 *
 * ****...****/  (100 chars total)
```

Tier 2 — Section marker. Divides file into major logical blocks. Uses = border.
Interior blank comment lines above and below the name.
```c
/* ====...====   (100 chars total)
 *
 * SECTION NAME
 *
 * ====...===*/  (100 chars total)
```

Tier 3 — Block label. Labels a specific cluster within a section. Uses - border.
Name sits tight, no interior blank lines. Grammar is Bin : Name.
```c
/* ----...----   (100 chars total)
 * Bin : Name
 * ----...---*/  (100 chars total)
```

**C border math:**
- Open bar: `/* ` (3 chars) + fill to 100 = 97 fill chars
- Close bar: ` * ` (3 chars) + fill (95 chars) + `*/` (2 chars) = 100 total
- The `*/` asymmetry is a C preprocessor constraint, not a style choice

**Whitespace rules:**
- Two blank lines between end of one section and next section marker
- One blank line between block label and first content line
- One blank line between last content line and next marker
- No blank lines between tightly related declarations within a block

**Five-term parameter contract (Law):**
Every function with two or more parameters carries this annotation.
Five terms, column-aligned, one parameter per line.
```c
i64 blob_make(
    VALID    CONSUME   ALWAYS      KEEP  NONE  const char  *path,
    GARBAGE  POPULATE  IF_SUCCESS  KEEP  NONE  u8         **blob_out,
    GARBAGE  POPULATE  IF_SUCCESS  NONE  NONE  u64         *length_out
);
```
Terms: STATE, ACTION, CONTRACT, CONTROL, LAYER_TWO_DIAGNOSTIC

**C block bin vocabulary (eleven bins):**
Definition, Type, Interface, Operation, Table, Dispatch, Machine, Transform,
Policy, Guard, Callback

**Makefile block bin vocabulary (eleven bins):**
Configuration, Discovery, Derivation, Conditional, Rule, Vendor Rule,
Generation, Test, Infrastructure, Maintenance, Installation

**Naming:** Full words only. No abbreviations. `error` not `err`, `buffer` not
`buf`. Every macro carries prefix `COMPILE_TIME_ENFORCEMENT_FRAMEWORK_`.

---

## THE NEOVIM CONFIG ARCHITECTURE

Repo: github.com/ZacharyTPerry-lang/nvim-config

```
~/.config/nvim/
    init.lua
    lua/
        strato/
            init.lua          — entry point, requires all submodules
            set.lua           — vim options only
            remap.lua         — ALL keybinds here, none elsewhere
            lazy_init.lua     — lazy.nvim bootstrap
            snippets_init.lua — snippet system entry point (NEW)
            lazy/
                snippets.lua  — LuaSnip plugin setup
            snippets/         — NEW: snippet system lives here
                c.lua
                shared/
                    vocabulary.lua
                    highlights.lua
                    borders.lua
                    generators.lua
```

**Critical architecture rules:**
- Keybinds belong only in remap.lua. Never put keybinds in plugin setup files.
- snippets_init.lua is required from strato/init.lua.
- The lua-loader discovers filetype files directly inside strato/snippets/.
  Files inside shared/ are NOT auto-discovered — they are required explicitly.

**Existing LuaSnip keybinds (already wired in snippets.lua):**
- `<C-s>e` — expand snippet at cursor (insert mode)
- `<C-s>;` — jump forward to next tabstop (insert + select mode)
- `<C-s>,` — jump backward to previous tabstop (insert + select mode)
- `<C-E>` — cycle choice node (insert + select mode)

**Taken insert-mode Ctrl binds (DO NOT CONFLICT):**
`<C-g>` `<C-b>` `<C-v>` `<C-l>` `<C-n>` `<C-j>` `<C-k>` `<C-f>` `<C-d>`
`<C-u>` `<C-e>` `<C-CR>` `<C-s>e` `<C-s>;` `<C-s>,` `<C-E>`

---

## THE SNIPPET SYSTEM — WHAT WAS BUILT

### Design decisions locked in

**Two-tier discovery:**
- Quicklist (trigger + expand): three border snippets use triggers `fh`, `sm`,
  `bl`. Filetype-detected — same trigger expands differently per filetype.
- Telescope picker: one bind opens a fuzzy-searchable list of all snippets.
  Everything that is not a border goes here. Bind not yet wired.

**Storage architecture:**
- One file per filetype under strato/snippets/
- Shared utilities under strato/snippets/shared/
- Shared files loaded via ls_tracked_dopackage for hot-reload dependency tracking
- Description strings on every snippet — these are the telescope-searchable index

**Programmatic generation:**
- vocabulary.lua holds all term lists as Lua tables
- borders.lua holds border string generation logic
- generators.lua holds factory functions that build LuaSnip snippet objects
- Each filetype file calls generators rather than constructing snippets directly
- Adding a new bin or contract term requires editing vocabulary.lua only

**Highlight system:**
- Four custom highlight groups defined in highlights.lua
- Groups link to colorscheme semantic roles (not hardcoded hex) so theme
  switches preserve the hierarchy distinction
- StratoFileHeader → Title
- StratoSection → Statement
- StratoBlock → Comment
- StratoBlockName → Special
- Pattern matching to apply these groups is NOT yet built (future work)

### Files produced and their current state

**strato/snippets_init.lua** — COMPLETE
Entry point. Calls highlights.setup() and wires the lua-loader to
strato/snippets/.

**strato/snippets/shared/vocabulary.lua** — COMPLETE (operator patched
whitespace)
All term lists as Lua tables. Contract terms by column, C bins, Makefile bins,
assertion families. This is the single source of truth — edit here, everything
regenerates.

**strato/snippets/shared/highlights.lua** — COMPLETE
Four highlight groups. Minimal shim. setup() function called from
snippets_init.lua.

**strato/snippets/shared/borders.lua** — COMPLETE
Border string generators. C-family gets asymmetric `/* */` borders. All other
filetypes get symmetric single-prefix bars. M.get(filetype) returns a table of
three functions: file_header, section, block.

**strato/snippets/shared/generators.lua** — COMPLETE WITH KNOWN TODO
Three generator functions: make_file_header, make_section_marker,
make_block_label. Each takes a filetype string and returns a LuaSnip snippet.
M.build(filetype) returns all three as a table.

KNOWN ISSUE (flagged in file with TODO comments): The prefix logic for
non-C filetypes is duplicated inline in all three generator functions instead
of delegating cleanly to borders.lua. This must be refactored once the basic
snippet shape is confirmed working in a live Neovim session.

**strato/snippets/c.lua** — COMPLETE (minimal, intentionally)
Calls generators.build("c") and returns the result. Three snippets registered:
fh, sm, bl. This is the test file — the full pipeline must be confirmed working
here before adding more snippets.

### What has NOT been built yet

The following C snippets are the immediate next work, to be added to c.lua:

1. **Include guard** — trigger `ig`. Auto-populates filename via
   vim.fn.expand("%:t:r"):upper() transformed to match the convention.
   Full guard shape:
   ```c
   #ifndef COMPILE_TIME_ENFORCEMENT_FRAMEWORK_<FILENAME>_H
   #define COMPILE_TIME_ENFORCEMENT_FRAMEWORK_<FILENAME>_H

   [cursor]

   #endif
   ```

2. **Function signature scaffold** — trigger `fn`. Return type tabstop, name
   tabstop, multi-line contract params (use cp snippet to fill), closing paren,
   brace on own line, declarations block, blank line, body tabstop.

3. **Single contract parameter line** — trigger `cp`. Five column-aligned
   tabstops for STATE, ACTION, CONTRACT, CONTROL, LAYER_TWO_DIAGNOSTIC, then
   type tabstop, then name tabstop. Column widths are fixed by the longest term
   in each column:
   - STATE: 7 chars (GARBAGE)
   - ACTION: 8 chars (POPULATE)
   - CONTRACT: 10 chars (IF_SUCCESS)
   - CONTROL: 4 chars (KEEP)
   - LAYER_TWO_DIAGNOSTIC: 10 chars (PROVENANCE)

4. **Gate pattern** — trigger `gp`.
   ```c
   if (GATE_<subject>_IS_<predicate>(<value>) == STATE_<z>) {
       return ASSERTION_<FAMILY>_VIOLATION;
   }
   ```
   Three tabstops: subject/predicate, value, family.

5. **Error return** — trigger `er`.
   ```c
   return ASSERTION_<FAMILY>_VIOLATION;
   ```
   One tabstop: family name. Consider choice node from vocabulary.assertion_families.

6. **Strong typedef** — trigger `td`.
   ```c
   typedef struct { <type> value; } <Name>;
   ```
   Two tabstops: inner type, name.

7. **Static function scaffold** — trigger `sf`. Same as fn but with static
   prefix.

After C is fully built and tested, the pattern replicates to:
- cpp.lua (same as c.lua, filetype = "cpp")
- fortran.lua
- make.lua
- markdown.lua

The telescope picker wiring (plugin addition + remap.lua bind) has not been
done yet. This is a separate piece of work after the C snippets are complete.

The highlight pattern matching (Treesitter queries or regex autocmds that apply
StratoFileHeader/StratoSection/StratoBlock/StratoBlockName to actual comment
borders in buffers) has not been built. This is deferred.

---

## FIRST THING TO DO IN THE NEXT SESSION

Before writing any new snippet, the operator must test the current system in a
live Neovim session:

1. Confirm strato/init.lua has `require("strato.snippets_init")` added
2. Open a .c file
3. Type `fh` then hit `<C-s>e` — file header should expand with filename
   auto-populated
4. Type `sm` then hit `<C-s>e` — section marker should expand
5. Type `bl` then hit `<C-s>e` — block label should expand with two tabstops

If any of these fail, fix the pipeline before adding new snippets. The most
likely failure points are:

- The generators.lua TODO refactor causing a nil error on the borders call
- The lua-loader path in snippets_init.lua not resolving correctly
- The highlights.lua require path failing if vocabulary/highlights were not
  moved to strato/snippets/shared/ correctly

Do not proceed to new snippets until fh/sm/bl are confirmed working.
