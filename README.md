# GZ302 Linux Setup - Fresh Start

**Version: 0.0.1-beta**

This repository has been reset to start fresh from version 0.0.1-beta.

## Current State

The repository now contains only:
- `.github/copilot-instructions.md` - Development guidelines (cleaned of previous repo-specific content)
- `.gitignore` - Ignores the backup folder
- `backup/` - Complete archive of the previous version (0.1.4-pre-release)

## Backup

A complete backup of the previous repository state (version 0.1.4-pre-release) is stored in the `backup/` folder. This includes all scripts, documentation, and legacy files.

The backup folder is ignored by git and will not be committed or pushed to the repository.

## Manual Cleanup Required

⚠️ **Important**: The following items need to be manually cleaned up by the repository owner:

### 1. Delete Old Branches
All old branches should be deleted from GitHub, keeping only:
- `main` branch
- This cleanup branch (can be merged and deleted after review)

To delete old branches:
```bash
# List all remote branches
git branch -r

# Delete remote branches (run from GitHub web interface or CLI)
git push origin --delete <branch-name>
```

### 2. Close/Delete Old Issues
Review and close or delete all existing GitHub issues that pertain to the old version.

### 3. Close/Delete Old Pull Requests
Review and close or delete all existing pull requests that pertain to the old version.

### 4. Update Repository Description
Update the GitHub repository description to reflect the fresh start at version 0.0.1-beta.

### 5. Clear Release History (Optional)
Consider deleting old releases from the GitHub releases page if starting completely fresh.

### 6. Update GitHub Settings
- Update repository topics/tags as needed
- Update README preview if displayed
- Review and update any repository settings as needed

## Next Steps

After manual cleanup is complete:
1. Create new project structure for version 0.0.1-beta
2. Add initial documentation (README.md, CONTRIBUTING.md, etc.)
3. Begin fresh development

## Notes

- The backup folder contains everything from the previous version and can be used for reference
- The copilot instructions have been cleaned of repo-specific content but retain the general development workflow guidelines
- Version starts at 0.0.1-beta to indicate early development stage

---

**Last Updated**: October 14, 2025  
**Previous Version**: 0.1.4-pre-release (archived in backup/)
