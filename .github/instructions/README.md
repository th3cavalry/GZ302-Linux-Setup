# GitHub Copilot Instructions

This directory contains reference files for GitHub Copilot instructions used in the GZ302-Linux-Setup repository.

## Main Project Instructions

All repository-wide instructions are now consolidated in:
- **`.github/copilot-instructions.md`** - Complete instructions including:
  - Beast Mode 3.1 autonomous problem-solving methodology
  - Memory system for user preferences and context
  - GZ302-specific hardware details and validation commands
  - Development guidelines and best practices

## Reference Files

This directory contains the original instruction files that have been incorporated into the main copilot-instructions.md:

### beast-mode.instruction.md
**Beast Mode 3.1** - Comprehensive autonomous problem-solving instructions (now integrated into main file):
- Work autonomously until problems are completely resolved
- Perform extensive internet research using fetch_webpage
- Create detailed todo lists and track progress
- Test rigorously and handle all edge cases
- Make incremental, well-tested changes

### memory.instruction.md
**Memory System** - User preferences and context storage (now integrated into main file):
- User preferences and working style
- Project context and conventions
- Custom configurations and settings

## Why the Consolidation?

The Beast Mode and Memory instructions have been incorporated into the main `.github/copilot-instructions.md` file to ensure they are repository-wide and always active. This provides:

1. **Consistent behavior** - All instructions in one place
2. **Easier maintenance** - Single file to update
3. **Better discoverability** - Everything in the main instructions
4. **No conflicts** - Unified instruction set

## Usage

The instructions are automatically used by GitHub Copilot when working in this repository. No additional setup is required.

Users can:
- Request memory updates: "Remember that I prefer X"
- Request autonomous problem-solving: "Use Beast Mode to solve this"
- Ask for clarification: "What instructions are you following?"

All instructions are found in the main `.github/copilot-instructions.md` file.
