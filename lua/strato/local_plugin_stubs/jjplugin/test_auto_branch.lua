-- Test script for auto-branching loop
-- Run in nvim with :source test_auto_branch.lua

local state = require('strato.local_plugin_stubs.jjplugin.state')
local diff = require('strato.local_plugin_stubs.jjplugin.diff')

print("=== Complete JJ Plugin Test ===\n")

-- Test 1: Create major
print("Test 1: Create major with :JJMajor")
print("Run: :JJMajor test implementation")
print("Expected: Major A created, set as current\n")

-- Test 2: Visualize tree
print("Test 2: Visualize tree")
print("Run: :JJTree")
print("Expected: Tree window opens showing Major A\n")

-- Test 3: Check drift
print("Test 3: Check drift status")
print("Run: :JJDrift")
print("Expected: Shows drift=0, threshold=500\n")

-- Test 4: Create minor
print("Test 4: Create sibling minor")
print("First create a minor under A:")
print("Run: :JJMinor optimization attempt")
print("Expected: Creates A.1, switches to it\n")

-- Test 5: Freeze workflow
print("Test 5: Freeze/unfreeze")
print("Run: :JJFreeze")
print("Expected: Node frozen, next edit creates child")
print("Run: :JJUnfreeze")
print("Expected: Node unfrozen\n")

-- Test 6: Add lines to trigger auto-branch
print("Test 6: Add 600 lines to trigger auto-branch")
print("Run in insert mode or:")
print(":lua for i=1,600 do vim.api.nvim_buf_set_lines(0, -1, -1, false, {'line ' .. i}) end")
print(":w")
print("Expected: Auto-branch notification, drift reset\n")

-- Test 7: Check tree after auto-branch
print("Test 7: View tree after auto-branch")
print("Run: :JJTree")
print("Expected: See parent frozen, child created\n")

-- Test 8: Switch nodes
print("Test 8: Switch between nodes")
print("Run: :JJSwitch A")
print("Expected: Switch back to major A\n")

-- Test 9: Verify persistence
print("Test 9: Check metadata file")
print("Run: :!cat .jj-tree-metadata.json | jq")
print("Expected: JSON with tree structure\n")

-- Quick validation function
local function quick_test()
    local fp = vim.fn.expand('%:.')

    if not state.file_has_tree(fp) then
        print("\nNo tree yet. Run: :JJMajor <description>")
        return
    end

    local fs = state.get_file_state(fp)

    print("\nQuick Status:")
    print("  File:", fp)
    print("  Current path:", vim.inspect(fs.current_path))
    print("  Drift:", state.get_drift(fp))
    print("  Anchor:", state.get_anchor(fp))

    if #fs.current_path > 0 then
        local node = state.get_current_node(fp)
        if node then
            print("\n  Current node:")
            print("    ID:", node.id)
            print("    Description:", node.description)
            print("    Frozen:", node.frozen)
            print("    Main:", node.is_main)
            print("    Commit:", node.main_commit)
        end
    end

    print("\n  Majors:")
    for id, major in pairs(fs.majors) do
        print(string.format("    %s: %s (main=%s, frozen=%s)",
            id, major.description, major.is_main, major.frozen))
    end

    print("\n  Available commands:")
    print("    :JJTree      - Visualize full tree")
    print("    :JJDrift     - Detailed drift status")
    print("    :JJMinor     - Create sibling minor")
    print("    :JJFreeze    - Lock current node")
    print("    :JJSwitch    - Navigate to node")
end

-- Add command to run quick test
vim.api.nvim_create_user_command('JJTest', quick_test, {})

print("\nHelper command added: :JJTest")
print("Run :JJTest anytime to see current state\n")
print("=== Setup complete ===")
