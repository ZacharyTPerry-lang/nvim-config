JJ Plugin - Command Reference
=============================

TREE MANAGEMENT
---------------

:JJMajor <description>
  Create new major version (top-level branch)
  Example: :JJMajor async implementation
  Creates: Major A, B, C, etc.

:JJMinor <description>
  Create sibling minor version (parallel exploration)
  Example: :JJMinor optimization attempt
  Creates: A1, A2, etc. at same depth level
  Note: Must be in a minor to create sibling minors

:JJCommit [description]
  Manual checkpoint (freezes current, creates child)
  Example: :JJCommit end of day
  Auto-generates timestamp if no description


NODE OPERATIONS
---------------

:JJFreeze
  Lock current node (make immutable)
  Next edit will automatically create child
  Use for "known good" states

:JJUnfreeze
  Unlock current node
  Resume editing without branching


NAVIGATION
----------

:JJSwitch <path>
  Switch to different node in tree
  Examples:
    :JJSwitch A          - Switch to major A
    :JJSwitch A1         - Switch to A's first minor
    :JJSwitch A1.2       - Switch to A1's second child
    :JJSwitch A1.2.1     - Arbitrary depth supported


VISUALIZATION
-------------

:JJTree
  Show tree structure in split window
  Displays:
    - [MAIN] nodes
    - [FROZEN] nodes
    - Current position with →
    - Drift amounts
    - Tree hierarchy

:JJDrift
  Show drift status for current node
  Displays:
    - Stored drift
    - Real-time drift
    - Progress to threshold (500 lines)
    - Progress bar
    - Anchor commit


BASIC JJ OPERATIONS
-------------------

:JJStatus
  Show jj working copy status

:JJLog
  Show commit history

:JJEdit <change_id>
  Switch to specific jj change

:JJDescribe <description>
  Update current commit description


AUTO-BRANCHING BEHAVIOR
-----------------------

Automatic child creation occurs when:

1. Cumulative drift exceeds 500 lines (configurable)
   - Deletions count fully
   - Modifications count fully
   - Small additions (<10 lines) ignored
   - Large additions (>10 lines) count

2. Editing a frozen node
   - Immediate child creation
   - No drift check needed

When auto-branch triggers:
  - Parent node frozen automatically
  - Child node created with timestamp
  - Drift counter reset to 0
  - New anchor set to child commit


WORKFLOW EXAMPLES
-----------------

Example 1: Simple linear development
  :JJMajor baseline
  # edit, save repeatedly
  # auto-branch at 500 lines
  # continue editing in child

Example 2: Parallel hypothesis testing
  :JJMajor approach A
  # work on A
  :JJSwitch A
  :JJMajor approach B
  # work on B
  :JJTree  # compare both

Example 3: Safe experimentation
  :JJFreeze  # lock current state
  # make risky changes
  # if good: continue in child
  # if bad: :JJSwitch back to parent

Example 4: Multiple refinements
  :JJMajor baseline
  :JJMinor optimization 1
  # work
  :JJSwitch A  # back to baseline
  :JJMinor optimization 2
  # work
  :JJTree  # see both approaches


KEYBOARD SHORTCUTS (none by default)
-------------------------------------

Suggested mappings (add to your config):

  vim.keymap.set('n', '<leader>jt', ':JJTree<CR>')
  vim.keymap.set('n', '<leader>jd', ':JJDrift<CR>')
  vim.keymap.set('n', '<leader>jf', ':JJFreeze<CR>')
  vim.keymap.set('n', '<leader>ju', ':JJUnfreeze<CR>')


METADATA FILE
-------------

Tree structure stored in: .jj-tree-metadata.json
  - Auto-created in repo root
  - JSON format
  - Version controlled (recommended)
  - Persisted on every state change


TROUBLESHOOTING
---------------

Tree not showing up?
  1. Ensure in jj repo (:JJStatus should work)
  2. Create initial major with :JJMajor
  3. Check metadata: :!cat .jj-tree-metadata.json

Auto-branch not triggering?
  1. Check drift: :JJDrift
  2. Ensure >500 lines changed
  3. Check if node is frozen (immediate branch)

Commands not available?
  1. Check plugin loaded: :lua print(vim.inspect(require('strato.local_plugin_stubs.jjplugin').get_state()))
  2. Verify jj binary: :!which jj
  3. Restart nvim

Tree visualization empty?
  1. Must have at least one major
  2. Run :JJMajor first
  3. Check state: :lua print(vim.inspect(require('strato.local_plugin_stubs.jjplugin.state').get_file_state(vim.fn.expand('%:.'))))
