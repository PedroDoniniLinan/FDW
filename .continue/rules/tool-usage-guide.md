---
description: Guide for properly using Continue agent tools, especially those
  with known argument format issues
---

## Tool Usage Rules

### ✅ Working Tools (Use normally)

- **ls**: List directory contents
- **read_currently_open_file**: Read the file currently open in the IDE
- **file_glob_search**: Search files using glob patterns (e.g., `**/*.ts`)
- **view_diff**: View uncommitted changes (shows empty when no changes)
- **grep_search**: Search file contents using regex
- **run_terminal_command**: Execute bash commands
- **fetch_url_content**: Fetch web content from a URL
- **request_rule**: Request existing rules by name
- **read_skill**: Read existing skills by name

### ❌ Tools with Known Issues (Use with caution)

1. **read_file** - FAILS: "Cannot read properties of undefined"
   - **Workaround**: Use `read_currently_open_file` for open files, or rely on other tools

2. **create_new_file** - FAILS: Invalid arguments error
   - **Workaround**: Use `run_terminal_command` with `echo` or `cat > filepath << 'EOF'` to create files

3. **edit_existing_file** - Requires BOTH `filepath` and `changes` parameters
   - **Changes format**: Must include `old_string` (exact text to replace) and `new_string` (replacement text)
   - Ensure both parameters are always provided

4. **single_find_and_replace** - Parameter format issues
   - Use exact string matching in `old_string`
   - Preserve whitespace/indentation exactly

5. **create_rule_block** - Conflicting parameter requirements
   - Required: `name`, `rule`
   - Optional: `description`, `globs`, `regex`, `alwaysApply`
   - For "Always" or "Auto Attached": set `alwaysApply: true`
   - For "Agent Requested" or "Manual": set `alwaysApply: false`

### General Best Practices

- Always prefer working tools when possible
- When using failing tools, double-check parameter format matches exactly what's expected
- Use `run_terminal_command` as a fallback for file operations that fail with dedicated tools
- Test tool calls in small steps before complex operations
