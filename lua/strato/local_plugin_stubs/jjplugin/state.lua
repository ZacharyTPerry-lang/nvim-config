-- ~/.config/nvim/lua/strato/local_plugin_stubs/jjplugin/state.lua
-- Tree-based VCS state management with persistence

local M = {}

-- Default configuration
local DEFAULT_CONFIG = {
    auto_split_threshold = 500,  -- Lines of cumulative drift before auto-branch
    small_addition_threshold = 10,  -- FIX: was "addiition"
    metadata_file = '.jj-tree-metadata.json',
}

-- Global state structure
local state = {
    available = false,
    repo_root = nil,

    -- Per-file tree tracking
    files = {},

    config = vim.deepcopy(DEFAULT_CONFIG),
}

-- ============================================================================
-- Basic State Operations (existing)
-- ============================================================================

function M.set_available(is_available)
    state.available = is_available
end

function M.is_available()
    return state.available
end

function M.set_repo(root)
    state.repo_root = root

    -- Auto-load metadata when repo changes
    if root then
        M.load()
    end
end

function M.get_repo()
    return state.repo_root
end

function M.in_repo()
    return state.repo_root ~= nil
end

function M.get_all()
    return vim.deepcopy(state)
end

function M.get_config()
    return vim.deepcopy(state.config)
end

function M.set_config(config)
    state.config = vim.tbl_deep_extend('force', state.config, config or {})
end

-- ============================================================================
-- File State Operations
-- ============================================================================

-- Initialize file state if it doesn't exist
local function ensure_file_state(filepath)
    if not state.files[filepath] then
        state.files[filepath] = {
            majors = {},
            current_path = {},
            anchor_commit = nil,
            deps = {},
        }
    end
end

-- Get complete state for a specific file
function M.get_file_state(filepath)
    ensure_file_state(filepath)
    return vim.deepcopy(state.files[filepath])
end

-- Check if file has any tree data
function M.file_has_tree(filepath)
    return state.files[filepath] ~= nil and next(state.files[filepath].majors) ~= nil
end

-- ============================================================================
-- Node Navigation
-- ============================================================================

-- Get node at specific path in tree
-- path = {"A", "A1", "A1.1"}
local function get_node_at_path(filepath, path)
    ensure_file_state(filepath)

    if #path == 0 then
        return nil
    end

    local file_state = state.files[filepath]
    local current = file_state.majors[path[1]]

    if not current then
        return nil
    end

    -- Traverse down the path
    for i = 2, #path do
        if not current.minors or not current.minors[path[i]] then
            return nil
        end
        current = current.minors[path[i]]
    end

    return current
end

-- FIX: Get current node for file (no path param!)
function M.get_current_node(filepath)
    ensure_file_state(filepath)
    local file_state = state.files[filepath]

    if #file_state.current_path == 0 then
        return nil
    end

    return get_node_at_path(filepath, file_state.current_path)
end

-- FIX: Set current position in tree (THIS WAS MISSING!)
function M.set_current_node(filepath, path)
    ensure_file_state(filepath)
    local file_state = state.files[filepath]

    -- Verify path exists
    local node = get_node_at_path(filepath, path)
    if not node then
        return false, "Path does not exist in tree"
    end

    file_state.current_path = vim.deepcopy(path)
    M.persist()
    return true
end

-- Get current path
function M.get_current_path(filepath)
    ensure_file_state(filepath)
    return vim.deepcopy(state.files[filepath].current_path)
end

-- ============================================================================
-- Node Creation and Management
-- ============================================================================

-- Generate next ID for siblings at same level
local function generate_next_id(parent_node, prefix)
    if not parent_node or not parent_node.minors then
        return prefix .. "1"
    end

    -- Find highest number
    local max_num = 0
    for id, _ in pairs(parent_node.minors) do
        local num = tonumber(id:match(prefix .. "(%d+)"))
        if num and num > max_num then
            max_num = num
        end
    end

    return prefix .. tostring(max_num + 1)
end

-- Add a new node to the tree
-- parent_path: path to parent node (empty for major)
-- node_data: { description, commit_id, is_main, frozen }
function M.add_node(filepath, parent_path, node_data)
    ensure_file_state(filepath)
    local file_state = state.files[filepath]

    node_data = node_data or {}

    -- Creating a major (top-level)
    if #parent_path == 0 then
        -- Generate major ID (A, B, C, ...)
        local next_id = string.char(65 + vim.tbl_count(file_state.majors))

        -- Determine is_main: explicit, or if it's the first major
        local should_be_main = false
        if node_data.is_main == true then
            should_be_main = true
        elseif node_data.is_main == nil then
            -- Auto: main if no other majors exist
            should_be_main = (vim.tbl_count(file_state.majors) == 0)
        end

        -- If setting as main, unset other majors
        if should_be_main then
            for _, major in pairs(file_state.majors) do
                major.is_main = false
            end
        end

        local major = {
            id = next_id,
            description = node_data.description or "Major " .. next_id,
            main_commit = node_data.commit_id,
            is_main = should_be_main,
            frozen = node_data.frozen or false,
            drift = 0,
            created_at = os.time(),
            minors = {},
        }

        file_state.majors[next_id] = major
        M.persist()
        return next_id, {next_id}
    end

    -- Creating a minor (child)
    local parent = get_node_at_path(filepath, parent_path)
    if not parent then
        return nil, nil, "Parent path does not exist"
    end

    if not parent.minors then
        parent.minors = {}
    end

    -- Determine is_main: explicit, or if no siblings
    local should_be_main = false
    if node_data.is_main == true then
        should_be_main = true
    elseif node_data.is_main == nil then
        -- Auto: main if no siblings exist
        should_be_main = (vim.tbl_count(parent.minors) == 0)
    end

    -- If setting as main, unset siblings
    if should_be_main then
        for _, minor in pairs(parent.minors) do
            minor.is_main = false
        end
    end

    -- Generate minor ID based on parent
    local parent_id = parent_path[#parent_path]
    local next_id = generate_next_id(parent, parent_id .. ".")

    local minor = {
        id = next_id,
        description = node_data.description or "Minor " .. next_id,
        main_commit = node_data.commit_id,
        is_main = should_be_main,
        frozen = node_data.frozen or false,
        drift = 0,
        created_at = os.time(),
        parent_id = parent_id,
        minors = {},
    }

    parent.minors[next_id] = minor

    -- Build full path
    local new_path = vim.deepcopy(parent_path)
    table.insert(new_path, next_id)

    M.persist()
    return next_id, new_path
end

-- ============================================================================
-- Node State Modification
-- ============================================================================

-- Freeze a node (make immutable)
function M.freeze_node(filepath, path)
    local node = get_node_at_path(filepath, path)
    if not node then
        return false, "Node not found"
    end

    node.frozen = true
    node.frozen_at = os.time()
    M.persist()
    return true
end

-- Unfreeze a node
function M.unfreeze_node(filepath, path)
    local node = get_node_at_path(filepath, path)
    if not node then
        return false, "Node not found"
    end

    node.frozen = false
    node.unfrozen_at = os.time()
    M.persist()
    return true
end

-- Check if node is frozen
function M.is_frozen(filepath, path)
    local node = get_node_at_path(filepath, path)
    return node and node.frozen or false
end

-- Close a node (mark as archived/merged)
function M.close_node(filepath, path)
    local node = get_node_at_path(filepath, path)
    if not node then
        return false, "Node not found"
    end

    node.closed = true
    node.closed_at = os.time()
    M.persist()
    return true
end

-- Set a node as main at its level
function M.set_main(filepath, path)
    if #path == 0 then
        return false, "Cannot set empty path as main"
    end

    local node = get_node_at_path(filepath, path)
    if not node then
        return false, "Node not found"
    end

    -- Clear main flag from siblings
    if #path == 1 then
        -- Major level
        local file_state = state.files[filepath]
        for _, major in pairs(file_state.majors) do
            major.is_main = false
        end
    else
        -- Minor level - get parent and clear siblings
        local parent_path = vim.list_slice(path, 1, #path - 1)
        local parent = get_node_at_path(filepath, parent_path)
        if parent and parent.minors then
            for _, minor in pairs(parent.minors) do
                minor.is_main = false
            end
        end
    end

    -- Set this node as main
    node.is_main = true
    M.persist()
    return true
end

-- Update node description
function M.set_node_description(filepath, path, description)
    local node = get_node_at_path(filepath, path)
    if not node then
        return false, "Node not found"
    end

    node.description = description
    node.description_updated_at = os.time()
    M.persist()
    return true
end

-- Update node's commit reference
function M.set_node_commit(filepath, path, commit_id)
    local node = get_node_at_path(filepath, path)
    if not node then
        return false, "Node not found"
    end

    node.main_commit = commit_id
    M.persist()
    return true
end

-- ============================================================================
-- Drift Tracking
-- ============================================================================

-- Update cumulative drift counter
function M.update_drift(filepath, lines)
    local node = M.get_current_node(filepath)
    if not node then
        return false, "No current node"
    end

    node.drift = (node.drift or 0) + lines
    M.persist()
    return true, node.drift
end

-- Reset drift counter
function M.reset_drift(filepath)
    local node = M.get_current_node(filepath)
    if not node then
        return false, "No current node"
    end

    node.drift = 0
    M.persist()
    return true
end

-- Get current drift
function M.get_drift(filepath)
    local node = M.get_current_node(filepath)
    if not node then
        return 0
    end
    return node.drift or 0
end

-- Set anchor commit for drift calculation
function M.set_anchor(filepath, commit_id)
    ensure_file_state(filepath)
    state.files[filepath].anchor_commit = commit_id
    M.persist()
    return true
end

-- Get anchor commit
function M.get_anchor(filepath)
    ensure_file_state(filepath)
    return state.files[filepath].anchor_commit
end

-- ============================================================================
-- Dependency Management
-- ============================================================================

-- Link file to another file's major version
function M.add_dependency(filepath, dep_filepath, dep_major, dep_minor)
    ensure_file_state(filepath)
    local file_state = state.files[filepath]

    if not file_state.deps then
        file_state.deps = {}
    end

    file_state.deps[dep_filepath] = {
        major = dep_major,
        pinned_minor = dep_minor,
        linked_at = os.time(),
    }

    M.persist()
    return true
end

-- Remove dependency
function M.remove_dependency(filepath, dep_filepath)
    ensure_file_state(filepath)
    local file_state = state.files[filepath]

    if file_state.deps then
        file_state.deps[dep_filepath] = nil
    end

    M.persist()
    return true
end

-- Get all dependencies for a file
function M.get_dependencies(filepath)
    ensure_file_state(filepath)
    local file_state = state.files[filepath]
    return vim.deepcopy(file_state.deps or {})
end

-- ============================================================================
-- Persistence
-- ============================================================================

-- Serialize state to JSON and save to repo
function M.persist()
    if not state.repo_root then
        return false, "Not in a jj repository"
    end

    local metadata_path = state.repo_root .. '/' .. state.config.metadata_file

    -- Prepare data for serialization
    local data = {
        version = "1.0.0",
        files = state.files,
        config = state.config,
        updated_at = os.time(),
    }

    -- Encode to JSON
    local json = vim.json.encode(data)

    -- Write to file
    local file = io.open(metadata_path, 'w')
    if not file then
        return false, "Failed to open metadata file for writing"
    end

    file:write(json)
    file:close()

    return true
end

-- Load state from JSON file in repo
function M.load()
    if not state.repo_root then
        return false, "Not in a jj repository"
    end

    local metadata_path = state.repo_root .. '/' .. state.config.metadata_file

    -- Check if file exists
    local file = io.open(metadata_path, 'r')
    if not file then
        -- No metadata yet, start fresh
        return true
    end

    -- Read file
    local content = file:read('*all')
    file:close()

    if not content or content == "" then
        return false, "Empty metadata file"
    end

    -- Decode JSON
    local ok, data = pcall(vim.json.decode, content)
    if not ok then
        return false, "Failed to parse metadata JSON: " .. tostring(data)
    end

    -- Restore state
    if data.files then
        state.files = data.files
    end

    if data.config then
        state.config = vim.tbl_deep_extend('force', state.config, data.config)
    end

    return true
end

-- Clear all state (for testing/reset)
function M.clear()
    state.files = {}
    if state.repo_root then
        M.persist()
    end
end

-- ============================================================================
-- Utility/Debug Functions
-- ============================================================================

-- Get all majors for a file
function M.get_majors(filepath)
    ensure_file_state(filepath)
    local majors = {}
    for id, major in pairs(state.files[filepath].majors) do
        table.insert(majors, {
            id = id,
            description = major.description,
            is_main = major.is_main,
            frozen = major.frozen,
        })
    end
    return majors
end

-- Walk tree and collect all nodes (for visualization)
function M.walk_tree(filepath)
    ensure_file_state(filepath)
    local file_state = state.files[filepath]
    local nodes = {}

    local function walk_recursive(node, path, depth)
        local node_info = {
            path = vim.deepcopy(path),
            id = node.id,
            description = node.description,
            is_main = node.is_main,
            frozen = node.frozen,
            closed = node.closed,
            drift = node.drift,
            depth = depth,
        }
        table.insert(nodes, node_info)  -- FIX: was "table.insert(node, node_info)"

        if node.minors then
            for id, minor in pairs(node.minors) do
                local minor_path = vim.deepcopy(path)
                table.insert(minor_path, id)
                walk_recursive(minor, minor_path, depth + 1)
            end
        end
    end

    -- Walk all majors
    for id, major in pairs(file_state.majors) do
        walk_recursive(major, {id}, 0)
    end

    return nodes
end

return M
