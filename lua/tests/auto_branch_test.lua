-- tests/auto_branch_test.lua
-- Specific test for auto-branching behavior
-- Run with :luafile tests/auto_branch_test.lua

local state = require('strato.local_plugin_stubs.jjplugin.state')
local diff = require('strato.local_plugin_stubs.jjplugin.diff')
local watcher = require('strato.local_plugin_stubs.jjplugin.watcher')

print("=== Auto-Branch Behavior Test ===\n")

if not state.in_repo() then
    print("ERROR: Not in jj repo")
    return
end

local test_file = vim.fn.expand('%:.')
if test_file == "" then
    print("ERROR: No file in buffer")
    return
end

print("Test file:", test_file)
print("This test will:")
print("  1. Create initial major")
print("  2. Add lines incrementally")
print("  3. Trigger auto-branch at threshold")
print("  4. Verify tree structure\n")

-- Clean start
state.clear()

-- Step 1: Create initial major
print("Step 1: Creating initial major...")
local commit_id = diff.get_current_commit()
if not commit_id then
    print("ERROR: Cannot get commit ID")
    return
end

local major_id, major_path = state.add_node(test_file, {}, {
    description = "auto-branch test baseline",
    commit_id = commit_id,
    is_main = true,
})

state.set_current_node(test_file, major_path)
state.set_anchor(test_file, commit_id)
state.reset_drift(test_file)

print(string.format("  ✓ Created major %s", major_id))
print(string.format("  ✓ Current path: %s", vim.inspect(major_path)))
print(string.format("  ✓ Anchor: %s", commit_id))
print(string.format("  ✓ Initial drift: %d\n", state.get_drift(test_file)))

-- Step 2: Simulate drift accumulation
print("Step 2: Simulating drift accumulation...")
print("  Adding lines in increments of 100...")

local bufnr = vim.api.nvim_get_current_buf()
local total_added = 0
local threshold = state.get_config().auto_split_threshold

for i = 1, 6 do
    -- Add 100 lines
    local lines = {}
    for j = 1, 100 do
        table.insert(lines, string.format("// Test line %d.%d", i, j))
    end
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
    total_added = total_added + 100

    -- Save
    vim.cmd('write')
    vim.cmd('sleep 100m')  -- Give time for file operations

    -- Update drift
    state.update_drift(test_file, 100)
    local current_drift = state.get_drift(test_file)

    print(string.format("  Increment %d: Added 100 lines (total: %d, drift: %d/%d)",
        i, total_added, current_drift, threshold))

    -- Check if we've hit threshold
    if current_drift >= threshold then
        print(string.format("  ⚠ THRESHOLD REACHED at %d lines!\n", current_drift))
        break
    end
end

-- Step 3: Check current state before auto-branch
print("Step 3: Pre-branch state check...")
local pre_path = state.get_current_path(test_file)
local pre_drift = state.get_drift(test_file)
local pre_frozen = state.is_frozen(test_file, pre_path)

print(string.format("  Current path: %s", vim.inspect(pre_path)))
print(string.format("  Current drift: %d", pre_drift))
print(string.format("  Is frozen: %s", pre_frozen))

if pre_drift < threshold then
    print(string.format("  ⚠ WARNING: Drift (%d) below threshold (%d)", pre_drift, threshold))
    print("  Adding more lines to exceed threshold...")

    local needed = threshold - pre_drift + 10
    local lines = {}
    for i = 1, needed do
        table.insert(lines, string.format("// Extra line %d", i))
    end
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
    vim.cmd('write')
    state.update_drift(test_file, needed)
    pre_drift = state.get_drift(test_file)
    print(string.format("  New drift: %d\n", pre_drift))
end

-- Step 4: Trigger auto-branch
print("Step 4: Triggering auto-branch...")
local auto_branch = require('strato.local_plugin_stubs.jjplugin.auto_branch')
local ok, err = auto_branch.create_auto_branch(test_file)

if not ok then
    print(string.format("  ✗ FAIL: Auto-branch failed: %s", err))
    return
end

print("  ✓ Auto-branch succeeded\n")

-- Step 5: Verify post-branch state
print("Step 5: Post-branch state verification...")
local post_path = state.get_current_path(test_file)
local post_drift = state.get_drift(test_file)
local parent_frozen = state.is_frozen(test_file, pre_path)

print(string.format("  Old path: %s", vim.inspect(pre_path)))
print(string.format("  New path: %s", vim.inspect(post_path)))
print(string.format("  Path depth increased: %s", #post_path > #pre_path))
print(string.format("  Parent frozen: %s", parent_frozen))
print(string.format("  New drift: %d", post_drift))

-- Verification checks
local checks_passed = 0
local checks_failed = 0

local function check(name, condition)
    if condition then
        print(string.format("  ✓ %s", name))
        checks_passed = checks_passed + 1
    else
        print(string.format("  ✗ %s", name))
        checks_failed = checks_failed + 1
    end
end

print("\nVerification:")
check("Path depth increased", #post_path > #pre_path)
check("Drift reset to 0", post_drift == 0)
check("Parent node frozen", parent_frozen)
check("Currently in child node", post_path[#post_path] ~= pre_path[#pre_path])

-- Step 6: Check tree structure
print("\nStep 6: Tree structure verification...")
local nodes = state.walk_tree(test_file)
print(string.format("  Total nodes: %d", #nodes))

-- Count frozen nodes
local frozen_count = 0
for _, node in ipairs(nodes) do
    if node.frozen then
        frozen_count = frozen_count + 1
    end
end
print(string.format("  Frozen nodes: %d", frozen_count))

check("At least one frozen node", frozen_count >= 1)

-- Step 7: Display tree
print("\nStep 7: Tree visualization:")
print("---")
for _, node in ipairs(nodes) do
    local indent = string.rep("  ", node.depth)
    local markers = {}
    if node.is_main then table.insert(markers, "MAIN") end
    if node.frozen then table.insert(markers, "FROZEN") end
    if vim.deep_equal(node.path, post_path) then table.insert(markers, "CURRENT") end

    local marker_str = #markers > 0 and ("[" .. table.concat(markers, ",") .. "] ") or ""
    print(string.format("%s%s%s: %s (drift: %d)",
        indent, marker_str, node.id, node.description, node.drift))
end
print("---\n")

-- Step 8: Test frozen node editing
print("Step 8: Testing frozen node editing...")
ok = state.set_current_node(test_file, pre_path)
if not ok then
    print("  ✗ Cannot switch to parent (it's frozen)")
else
    print("  ✓ Switched to parent")

    -- Try to trigger frozen edit
    print("  Simulating edit on frozen node...")
    ok, err = auto_branch.handle_frozen_edit(test_file)
    if ok then
        print("  ✓ Frozen edit created new child")
        local frozen_edit_path = state.get_current_path(test_file)
        print(string.format("  ✓ New path: %s", vim.inspect(frozen_edit_path)))
    else
        print(string.format("  ✗ Frozen edit failed: %s", err))
    end
end

-- Summary
print("\n" .. string.rep("=", 50))
print("Auto-Branch Test Summary")
print(string.rep("=", 50))
print(string.format("Verification checks passed: %d", checks_passed))
print(string.format("Verification checks failed: %d", checks_failed))

if checks_failed == 0 then
    print("\n✓ All auto-branch tests passed!")
    print("\nNext steps:")
    print("  1. Review tree: :JJTree")
    print("  2. Check commits: :JJLog")
    print("  3. Verify metadata: :!cat .jj-tree-metadata.json")
else
    print("\n✗ Some auto-branch tests failed")
    print("Review the output above for details")
end

print("\nNote: Buffer has been modified with test lines")
print("Current working copy should be in auto-branched child node")
