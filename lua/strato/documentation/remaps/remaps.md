# Complete Neovim Configuration Reference

**Philosophy**: Maximum efficiency through custom keybindings. Heavy remapping for ergonomics and speed.

---

## Table of Contents

1. [Core Setup](#core-setup)
2. [Navigation System](#navigation-system)
3. [Editing & Text Manipulation](#editing--text-manipulation)
4. [Search & Discovery](#search--discovery)
5. [LSP Integration](#lsp-integration)
6. [Window & Buffer Management](#window--buffer-management)
7. [Custom Movement System](#custom-movement-system)
8. [Symbol Insertion (Bracket Pairs)](#symbol-insertion-bracket-pairs)
9. [Special Modes](#special-modes)
10. [Disabled Keys](#disabled-keys)
11. [Build System](#build-system)

---

## Core Setup

### Leader Key
```
<Space> = Leader key
```

### File Explorer
| Keymap | Action |
|--------|--------|
| `<leader>f` | Open file explorer (netrw) |

---

## Navigation System

### File Navigation (Harpoon - Control Layer)

**Concept**: Mark your 4 most-used files for instant access.

| Keymap | Action |
|--------|--------|
| `<leader>a` | Add current file to harpoon |
| `<C-e>` | Toggle harpoon quick menu |
| `<C-h>` | Jump to harpoon file 1 |
| `<C-j>` | Jump to harpoon file 2 |
| `<C-k>` | Jump to harpoon file 3 |
| `<C-l>` | Jump to harpoon file 4 |
| `<C-S-P>` | Previous harpoon file |
| `<C-S-N>` | Next harpoon file |

**In Harpoon UI** (when `<C-e>` is open):
- `<C-v>` - Open in vsplit
- `<C-x>` - Open in split
- `<C-t>` - Open in new tab

### Custom HJKL System

**Default Vim HJKL is remapped to left-to-right home row order:**

| Keymap | Action | Vim Equivalent |
|--------|--------|----------------|
| `j` | Move left | `h` |
| `k` | Move down | `j` |
| `l` | Move up | `k` |
| `;` | Move right | `l` |

### Fast Vertical Movement

| Keymap | Action |
|--------|--------|
| `w` | Jump 10 lines down |
| `e` | Jump 10 lines up |

### Line Navigation

| Keymap | Action |
|--------|--------|
| `h` | Jump to first non-whitespace character |
| `'` | Jump to end of line |

### Block/Paragraph Navigation

| Keymap | Action |
|--------|--------|
| `n` | Next block (closing brace) |
| `m` | Previous block (opening brace) |

---

## Editing & Text Manipulation

### Smart Tab Indentation

**Custom implementation with cursor position preservation.**

#### Normal Mode
| Keymap | Action |
|--------|--------|
| `<Tab>` | Indent line right |
| `<S-Tab>` | Indent line left |

#### Visual Mode
| Keymap | Action |
|--------|--------|
| `<Tab>` | Indent selection right (keeps selection) |
| `<S-Tab>` | Indent selection left (keeps selection) |

#### Insert Mode
| Keymap | Action |
|--------|--------|
| `<Tab>` | Smart indent (maintains cursor position) |
| `<S-Tab>` | Smart dedent (maintains cursor position) |

**Note**: Custom functions prevent cursor jumping during indentation.

### Blank Line Insertion

| Keymap | Action |
|--------|--------|
| `<S-CR>` | Insert blank line below (stay in normal mode) |
| `<Tab><CR>` | Insert blank line above (stay in normal mode) |

### Auto-Comment Continuation

| Keymap | Action |
|--------|--------|
| `<C-CR>` (insert) | Continue comment on new line |

**Supports**:
- Lua (`-- `)
- C++ (`// `)
- Python (`# `)
- C block (`/* `)

**Preserves leading whitespace.**

### Escape Alternatives

| Keymap | Action |
|--------|--------|
| `jj` (insert) | Escape to normal mode |

**Timings**:
- `timeoutlen = 300ms` - Key sequence timeout
- `ttimeoutlen = 10ms` - Key code timeout

---

## Search & Discovery

### Telescope - File Finding

| Keymap | Action |
|--------|--------|
| `<leader>pf` | Find files by name |
| `<C-p>` | Git tracked files only |
| `<leader>fr` | Recent files (oldfiles) |

### Telescope - Content Search

| Keymap | Action |
|--------|--------|
| `<leader>lg` | Live grep (search as you type) |
| `<leader>ps` | Grep with prompt |
| `<leader>pws` | Grep word under cursor |
| `<leader>pWs` | Grep WORD under cursor (larger selection) |

### Telescope - Symbol Navigation (LSP)

| Keymap | Action |
|--------|--------|
| `<leader>ds` | Document symbols (outline current file) |
| `<leader>ws` | Workspace symbols (project-wide search) |

### Telescope - Utilities

| Keymap | Action |
|--------|--------|
| `<leader>fb` | Find buffers |
| `<leader>vh` | Help tags |
| `<leader>fh` | Command history |
| `<leader>fs` | Search history |
| `<leader>fm` | Marks |
| `<leader>fk` | Keymaps (search your bindings!) |
| `<leader>fo` | Vim options |
| `<leader>fR` | Registers |

---

## LSP Integration

**From init.lua autocmd on LspAttach:**

| Keymap | Action |
|--------|--------|
| `gd` | Go to definition |
| `K` | Hover documentation |
| `<leader>vws` | Workspace symbol search |
| `<leader>vd` | Open diagnostic float |
| `<leader>vca` | Code actions |
| `<leader>vrr` | Find all references |
| `<leader>vrn` | Rename symbol |
| `<C-h>` (insert) | Signature help |
| `[d` | Next diagnostic |
| `]d` | Previous diagnostic |

---

## Window & Buffer Management

### Window Navigation (Alt Layer)

| Keymap | Action |
|--------|--------|
| `<M-h>` | Move to left window |
| `<M-j>` | Move to bottom window |
| `<M-k>` | Move to top window |
| `<M-l>` | Move to right window |

### Window Resize (Alt Layer)

| Keymap | Action |
|--------|--------|
| `<M-Left>` | Decrease width |
| `<M-Right>` | Increase width |
| `<M-Up>` | Increase height |
| `<M-Down>` | Decrease height |

### Buffer Navigation (Alt Layer)

| Keymap | Action |
|--------|--------|
| `<M-n>` | Next buffer |
| `<M-p>` | Previous buffer |

### Buffer Management (Leader)

| Keymap | Action |
|--------|--------|
| `<leader>bd` | Delete buffer |
| `<leader>bD` | Force delete buffer (unsaved changes) |
| `<leader>fb` | Find buffer (telescope) |

---

## List Navigation (Bracket Pattern)

### Diagnostics (LSP)
| Keymap | Action |
|--------|--------|
| `[d` | Previous diagnostic |
| `]d` | Next diagnostic |

### Trouble (Error List)
| Keymap | Action |
|--------|--------|
| `[t` | Previous trouble item |
| `]t` | Next trouble item |
| `<leader>tt` | Toggle trouble window |

### Quickfix (Search Results)
| Keymap | Action |
|--------|--------|
| `[q` | Previous quickfix item |
| `]q` | Next quickfix item |
| `[Q` | First quickfix item |
| `]Q` | Last quickfix item |
| `<leader>qo` | Open quickfix window |
| `<leader>qc` | Close quickfix window |

### Location List (File-Local Quickfix)
| Keymap | Action |
|--------|--------|
| `[l` | Previous location |
| `]l` | Next location |
| `[L` | First location |
| `]L` | Last location |

---

## Symbol Insertion (Bracket Pairs)

**Fast access to symbols using Caps Lock → Ctrl mapping.**

### Opening Pairs (Left Hand)
| Keymap | Symbol | Mnemonic |
|--------|--------|----------|
| `<C-g>` (insert) | `{` | G for brace |
| `<C-b>` (insert) | `[` | B for bracket |
| `<C-v>` (insert) | `(` | V for paren |

### Closing Pairs (Right Hand)
| Keymap | Symbol | Mnemonic |
|--------|--------|----------|
| `<C-l>` (insert) | `}` | L for brace |
| `<C-n>` (insert) | `]` | N for bracket |
| `<C-j>` (insert) | `)` | J for paren |

### Operators
| Keymap | Symbol | Mnemonic |
|--------|--------|----------|
| `<C-k>` (insert) | `+` | K for plus |
| `<C-f>` (insert) | `=` | F for equal |
| `<C-d>` (insert) | `_` | D for underscore |
| `<C-u>` (insert) | `|` | U for pipe |

### Delete Forward
| Keymap | Action |
|--------|--------|
| `<C-e>` (insert) | Delete character forward |

---

## Special Modes

### Assembly Viewer

| Keymap | Action |
|--------|--------|
| `<leader>at` | Toggle assembly view |
| `<leader>al` | Cycle assembly mode (SPIR-V/PTX/SASS/AMD) |

### Dev Keyboard Layout

| Keymap | Action |
|--------|--------|
| `<F12>` | Toggle dev keyboard layout |

**Activates**:
- Caps Lock → Control
- Tap Control → Escape (via xcape)

### Vulkan Mode (ALL CAPS Typing)

| Keymap | Action |
|--------|--------|
| `dk` (insert) | Enter Vulkan mode |
| `<Esc>` (in Vulkan) | Exit Vulkan mode |
| `jj` (in Vulkan) | Exit Vulkan mode |

**Features**:
- All lowercase letters become uppercase
- Space becomes underscore (except after commas)
- Red cursor indicator
- Perfect for typing `VK_CONSTANT_NAMES`

**Status**: Check statusline for "VULKAN: ON/OFF"

**Usage**:
```
dk → VK_FORMAT_R8G8B8A8_UNORM
```

---

## Disabled Keys

### Visual Mode Disabled

| Keymap | Status |
|--------|--------|
| `v` | Disabled |
| `V` | Disabled |

**Rationale**: Preventing accidental visual mode activation.

### Insert Mode Disabled

| Keymap | Status |
|--------|--------|
| `a` | Disabled (use `I` for insert) |
| `<C-c>` | Disabled (use `jj` or `<Esc>`) |

### Mouse Actions Disabled

**All multi-click actions disabled**:
- Double-click (left/right/middle)
- Triple-click (left/right/middle)
- Quad-click (left/right/middle)
- Middle mouse button

**Rationale**: Force keyboard-only workflow.

---

## Build System

| Keymap | Action |
|--------|--------|
| `<leader>cc` | Compile current file |
| `<leader>cr` | Compile and run |
| `<leader>ca` | Run with arguments |
| `<leader>co` | Close build output |

**Commands**: `:CompileFile`, `:CompileRun`, `:CompileRunArgs`, `:CompileClose`

---

## Key Binding Layers Summary

### Control Layer (`<C-*>`)
- **Purpose**: File navigation (Harpoon)
- **Keys**: `h/j/k/l` for files 1-4, `e` for menu
- **Insert Mode**: Symbol insertion (brackets, operators)

### Alt Layer (`<M-*>`)
- **Purpose**: Window/buffer management
- **Keys**: `h/j/k/l` for window nav, `n/p` for buffers, arrows for resize

### Leader Layer (`<leader>*`)
- **Purpose**: Search, LSP, utilities, plugins
- **Prefix Groups**:
  - `p*` - Project/file finding
  - `f*` - Find (buffers, recent, marks, etc.)
  - `v*` - LSP actions
  - `q*` - Quickfix management
  - `b*` - Buffer management
  - `a*` - Assembly viewer
  - `c*` - Compile/build

### Bracket Pattern (`[*` / `]*`)
- **Purpose**: List navigation
- **Keys**: `d` (diagnostics), `t` (trouble), `q` (quickfix), `l` (location)

---

## Workflow Examples

### "Find function in current file and jump to it"
1. `<leader>ds` - Open document symbols
2. Type function name
3. `Enter` to jump

### "Search entire project for a string"
1. `<leader>lg` - Live grep
2. Type search term (live results)
3. `Enter` to open match
4. `]q` / `[q` to navigate results

### "Mark 4 files for rapid switching"
1. Open file A → `<leader>a`
2. Open file B → `<leader>a`
3. Open file C → `<leader>a`
4. Open file D → `<leader>a`
5. Now: `<C-h/j/k/l>` for instant access

### "Navigate splits while coding"
1. `<M-h/j/k/l>` - Move between windows
2. `<M-arrows>` - Resize as needed
3. `<M-n/p>` - Cycle buffers in current window

### "Type Vulkan constants quickly"
1. Enter insert mode
2. `dk` - Activate Vulkan mode
3. Type normally: `vk format r8g8b8a8 unorm`
4. Result: `VK_FORMAT_R8G8B8A8_UNORM`
5. `jj` - Exit Vulkan mode

### "Insert bracket pairs without reaching"
```
<C-g>  →  {
<C-v>some code<C-j>  →  (some code)
<C-b>index<C-n>  →  [index]
```

---

## Dependencies

### Required Plugins
- **Harpoon 2** - File marking
- **Telescope** - Fuzzy finder
- **nvim-lspconfig** - LSP integration
- **Trouble** - Error list UI
- **nvim-treesitter** - Syntax awareness
- **Focus.nvim** - Auto window resizing

### Local Plugins
- **asmview** - Assembly viewer for GPU/CPU code
- **map_nuance** - Dev keyboard layout (xcape)

---

## Technical Notes

### Lazy Loading
All telescope requires are wrapped in functions to prevent loading before plugins initialize:
```lua
vim.keymap.set('n', '<leader>pf', function()
    require('telescope.builtin').find_files()
end)
```

### Smart Indentation
Custom indent functions preserve cursor position during Tab operations, preventing the cursor from jumping to line start.

### Vulkan Mode Implementation
- Dynamically remaps all lowercase letters to uppercase
- Tracks state in global variable
- Changes cursor color to red for visual feedback
- Smart space handling (underscore vs space after comma)

### Harpoon UI Extensions
Custom extensions added for split/tab opening directly from Harpoon menu.

---

## Keybinding Conflicts (Intentional)

| Standard Vim | Remapped To | Reason |
|--------------|-------------|--------|
| `h/j/k/l` | `j/k/l/;` | Left-to-right home row order |
| `a` | Disabled | Prevent accidental insert |
| `v/V` | Disabled | Prevent accidental visual mode |
| `<C-c>` | Disabled | Force `jj` or `<Esc>` |

---

## Quick Reference Card

### Most Common Actions
```
Files:       <C-hjkl>    Harpoon 1-4
Search:      <leader>lg  Live grep
Symbols:     <leader>ds  Document outline
Move:        jkl;        Left/down/up/right
Windows:     <M-hjkl>    Navigate splits
Buffers:     <M-np>      Next/previous
Escape:      jj          Exit insert mode
Brackets:    <C-g/b/v>   {[(
```

---

**Version**: Based on remap.lua snapshot
**Last Updated**: 2025
