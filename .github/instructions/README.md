# GitHub Copilot Instructions

This directory contains custom instructions for GitHub Copilot to provide enhanced assistance when working on the GZ302-Linux-Setup repository.

## Instruction Files

### beast-mode.instruction.md
**Beast Mode 3.1** - Comprehensive autonomous problem-solving instructions that guide Copilot to:
- Work autonomously until problems are completely resolved
- Perform extensive internet research using fetch_webpage
- Create detailed todo lists and track progress
- Test rigorously and handle all edge cases
- Make incremental, well-tested changes

This mode is ideal for complex tasks that require deep investigation and comprehensive solutions.

### memory.instruction.md
**Memory System** - A persistent storage file for:
- User preferences and working style
- Project context and conventions
- Custom configurations and settings

Copilot can read and update this file when users request to "remember" information.

## Main Project Instructions

The main project-specific instructions are stored in:
- `.github/copilot-instructions.md` - GZ302-specific hardware, validation commands, and development guidelines

## How These Work Together

1. **beast-mode.instruction.md** - Provides the overall working methodology and autonomous behavior patterns
2. **memory.instruction.md** - Stores user-specific preferences and context
3. **copilot-instructions.md** - Contains project-specific technical details and validation procedures

All instruction files use YAML front matter with `applyTo: '**'` to apply globally to the repository.

## Usage

These instructions are automatically used by GitHub Copilot when working in this repository. No additional setup is required.

Users can:
- Request changes to memory: "Remember that I prefer X"
- Reference specific instructions: "Use Beast Mode to solve this"
- Ask for clarification: "What instructions are you following?"
