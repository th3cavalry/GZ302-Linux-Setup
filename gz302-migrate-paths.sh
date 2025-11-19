#!/bin/bash

# ==============================================================================
# GZ302 Path Migration Script
# Version: 1.0.0
#
# Migrates old custom paths to new standard default paths
# Automatically called by gz302-main.sh when old paths are detected
# ==============================================================================

set -euo pipefail

# Color codes for output
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m'

info() {
    echo -e "${C_BLUE}[MIGRATE]${C_NC} $1"
}

success() {
    echo -e "${C_GREEN}[SUCCESS]${C_NC} $1"
}

warning() {
    echo -e "${C_YELLOW}[WARNING]${C_NC} $1"
}

error() {
    echo -e "${C_RED}[ERROR]${C_NC} $1"
}

# Get the real user (not root when using sudo)
get_real_user() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    else
        logname 2>/dev/null || whoami
    fi
}

# Detect Ollama installation
detect_ollama() {
    # Check if Ollama is installed
    if command -v ollama >/dev/null 2>&1; then
        return 0
    fi
    
    # Check if Ollama service exists
    if systemctl list-unit-files | grep -q ollama; then
        return 0
    fi
    
    # Check if Ollama binary exists in common locations
    if [[ -f "/usr/local/bin/ollama" ]] || [[ -f "/usr/bin/ollama" ]]; then
        return 0
    fi
    
    return 1
}

# Ask user about Ollama migration
handle_ollama_migration() {
    if ! detect_ollama; then
        return 0
    fi
    
    echo
    warning "Ollama installation detected!"
    echo
    echo "The GZ302 setup has switched from Ollama to llama.cpp for better"
    echo "hardware support on the Strix Halo platform (AMD Radeon 8060S)."
    echo
    echo "llama.cpp benefits:"
    echo "  • Better ROCm/HIP integration for gfx1151 (Radeon 8060S)"
    echo "  • Optimized performance for AMD Strix Halo architecture"
    echo "  • Lower memory overhead"
    echo "  • More control over model loading and inference"
    echo
    echo "You have three options:"
    echo "  1. Keep Ollama (no changes, skip llama.cpp installation)"
    echo "  2. Install llama.cpp alongside Ollama (both available)"
    echo "  3. Remove Ollama and install llama.cpp (recommended for best performance)"
    echo
    
    if [[ -t 0 ]]; then
        read -r -p "Your choice [1/2/3]: " ollama_choice
        
        case "$ollama_choice" in
            1)
                info "Keeping Ollama. llama.cpp will NOT be installed."
                echo "KEEP_OLLAMA=true" > /tmp/.gz302-llm-choice
                return 0
                ;;
            2)
                info "Installing llama.cpp alongside Ollama."
                echo "INSTALL_BOTH=true" > /tmp/.gz302-llm-choice
                return 0
                ;;
            3)
                info "Will remove Ollama and install llama.cpp."
                echo "MIGRATE_TO_LLAMACPP=true" > /tmp/.gz302-llm-choice
                
                # Ask about model migration
                echo
                info "Checking for Ollama models to migrate..."
                local primary_user
                primary_user=$(get_real_user)
                local models_found=false
                
                # Check common Ollama model locations
                local ollama_model_dirs=(
                    "/home/$primary_user/.ollama/models"
                    "/usr/share/ollama/.ollama/models"
                    "/root/.ollama/models"
                )
                
                for model_dir in "${ollama_model_dirs[@]}"; do
                    if [[ -d "$model_dir" ]]; then
                        local model_count
                        model_count=$(find "$model_dir" -type f -name "*.bin" -o -name "*.gguf" 2>/dev/null | wc -l)
                        if [[ $model_count -gt 0 ]]; then
                            models_found=true
                            info "Found $model_count model file(s) in $model_dir"
                        fi
                    fi
                done
                
                if $models_found; then
                    echo
                    read -r -p "Would you like to migrate Ollama models to llama.cpp format? [Y/n]: " migrate_models
                    migrate_models="${migrate_models,,}"
                    if [[ -z "$migrate_models" || "$migrate_models" == "y" || "$migrate_models" == "yes" ]]; then
                        echo "MIGRATE_MODELS=true" >> /tmp/.gz302-llm-choice
                        info "Models will be migrated to ~/models/ for llama.cpp"
                    else
                        echo "MIGRATE_MODELS=false" >> /tmp/.gz302-llm-choice
                        info "Models will not be migrated (you can copy them manually later)"
                    fi
                else
                    info "No Ollama models found to migrate"
                fi
                
                # Stop and disable Ollama service
                if systemctl is-active ollama >/dev/null 2>&1; then
                    info "Stopping Ollama service..."
                    systemctl stop ollama || true
                fi
                if systemctl is-enabled ollama >/dev/null 2>&1; then
                    info "Disabling Ollama service..."
                    systemctl disable ollama || true
                fi
                
                # Uninstall Ollama based on package manager
                info "Removing Ollama..."
                if command -v pacman >/dev/null 2>&1; then
                    pacman -R --noconfirm ollama 2>/dev/null || true
                elif command -v apt >/dev/null 2>&1; then
                    apt remove -y ollama 2>/dev/null || true
                elif command -v dnf >/dev/null 2>&1; then
                    dnf remove -y ollama 2>/dev/null || true
                elif command -v zypper >/dev/null 2>&1; then
                    zypper remove -y ollama 2>/dev/null || true
                fi
                
                # Remove Ollama binary if installed via script
                if [[ -f "/usr/local/bin/ollama" ]]; then
                    rm -f /usr/local/bin/ollama
                fi
                if [[ -f "/usr/bin/ollama" ]]; then
                    rm -f /usr/bin/ollama
                fi
                
                success "Ollama removed successfully"
                return 0
                ;;
            *)
                warning "Invalid choice. Defaulting to option 2 (install both)."
                echo "INSTALL_BOTH=true" > /tmp/.gz302-llm-choice
                return 0
                ;;
        esac
    else
        # Non-interactive: default to installing both
        info "Non-interactive mode: Installing llama.cpp alongside Ollama"
        echo "INSTALL_BOTH=true" > /tmp/.gz302-llm-choice
        return 0
    fi
}

# Detect old custom paths
detect_old_paths() {
    local found_old_paths=false
    
    # Check for old llama.cpp installation
    if [[ -d "/opt/llama.cpp" ]]; then
        info "Found old llama.cpp installation at /opt/llama.cpp"
        found_old_paths=true
    fi
    
    # Check for old Python venv
    local primary_user
    primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" && -d "/home/$primary_user/.gz302-llm-venv" ]]; then
        info "Found old Python venv at /home/$primary_user/.gz302-llm-venv"
        found_old_paths=true
    fi
    
    # Check for old frontend directories
    if [[ -d "/home/$primary_user/.local/share/gz302/frontends" ]]; then
        info "Found old frontend directories at /home/$primary_user/.local/share/gz302/frontends"
        found_old_paths=true
    fi
    
    # Check for Ollama (also considered a "legacy" install needing migration decision)
    if detect_ollama; then
        info "Found Ollama installation"
        found_old_paths=true
    fi
    
    if $found_old_paths; then
        return 0
    else
        return 1
    fi
}

# Migrate llama.cpp from /opt/llama.cpp to /usr/local
migrate_llama_cpp() {
    if [[ ! -d "/opt/llama.cpp" ]]; then
        return 0
    fi
    
    info "Migrating llama.cpp from /opt/llama.cpp to /usr/local..."
    
    # Check if binaries exist in old location
    if [[ -d "/opt/llama.cpp/bin" ]]; then
        # Copy binaries to /usr/local/bin if they don't exist there
        for binary in llama-cli llama-server llama-quantize; do
            if [[ -f "/opt/llama.cpp/bin/$binary" ]]; then
                if [[ ! -f "/usr/local/bin/$binary" ]]; then
                    cp "/opt/llama.cpp/bin/$binary" "/usr/local/bin/"
                    chmod +x "/usr/local/bin/$binary"
                    info "Copied $binary to /usr/local/bin"
                else
                    info "$binary already exists in /usr/local/bin, skipping"
                fi
            fi
        done
        
        # Copy libraries if they exist
        if [[ -d "/opt/llama.cpp/lib" ]]; then
            mkdir -p /usr/local/lib
            cp -r /opt/llama.cpp/lib/* /usr/local/lib/ 2>/dev/null || true
            ldconfig 2>/dev/null || true
        fi
        
        # Remove old directory
        info "Removing old /opt/llama.cpp directory..."
        rm -rf /opt/llama.cpp
        success "llama.cpp migration complete"
    fi
}

# Migrate Python venv from .gz302-llm-venv to llm-venv
migrate_python_venv() {
    local primary_user
    primary_user=$(get_real_user)
    
    if [[ "$primary_user" == "root" ]]; then
        return 0
    fi
    
    local old_venv="/home/$primary_user/.gz302-llm-venv"
    local new_venv="/home/$primary_user/llm-venv"
    
    if [[ ! -d "$old_venv" ]]; then
        return 0
    fi
    
    info "Migrating Python venv from $old_venv to $new_venv..."
    
    # If new venv doesn't exist, move the old one
    if [[ ! -d "$new_venv" ]]; then
        mv "$old_venv" "$new_venv"
        chown -R "$primary_user:$(id -gn "$primary_user")" "$new_venv"
        
        # Update marker files
        if [[ -f "$new_venv/.torch_install_failed" ]]; then
            # Already using new path
            :
        elif [[ -d "$new_venv/.gz302" ]]; then
            # Migrate .gz302 directory contents to hidden files
            if [[ -f "$new_venv/.gz302/torch_install_failed" ]]; then
                mv "$new_venv/.gz302/torch_install_failed" "$new_venv/.torch_install_failed"
            fi
            if [[ -f "$new_venv/.gz302/torch_install_success" ]]; then
                mv "$new_venv/.gz302/torch_install_success" "$new_venv/.torch_install_success"
            fi
            rmdir "$new_venv/.gz302" 2>/dev/null || true
        fi
        
        success "Python venv migrated to $new_venv"
    else
        warning "New venv already exists at $new_venv, keeping both (manual cleanup recommended)"
    fi
}

# Migrate frontend directories from .local/share/gz302/frontends to home
migrate_frontends() {
    local primary_user
    primary_user=$(get_real_user)
    
    if [[ "$primary_user" == "root" ]]; then
        return 0
    fi
    
    local old_frontends="/home/$primary_user/.local/share/gz302/frontends"
    
    if [[ ! -d "$old_frontends" ]]; then
        return 0
    fi
    
    info "Migrating frontend directories from $old_frontends to /home/$primary_user/..."
    
    # Move each frontend directory
    for frontend_dir in "$old_frontends"/*; do
        if [[ -d "$frontend_dir" ]]; then
            local frontend_name
            frontend_name=$(basename "$frontend_dir")
            local new_location="/home/$primary_user/$frontend_name"
            
            if [[ ! -d "$new_location" ]]; then
                mv "$frontend_dir" "$new_location"
                chown -R "$primary_user:$(id -gn "$primary_user")" "$new_location"
                info "Moved $frontend_name to $new_location"
            else
                warning "$new_location already exists, skipping $frontend_name"
            fi
        fi
    done
    
    # Remove old directory structure
    if [[ -d "$old_frontends" ]]; then
        rmdir "$old_frontends" 2>/dev/null || true
        rmdir "/home/$primary_user/.local/share/gz302" 2>/dev/null || true
    fi
    
    success "Frontend directories migrated"
}

# Migrate Ollama models to llama.cpp format
migrate_ollama_models() {
    # Check if model migration was requested
    if [[ ! -f "/tmp/.gz302-llm-choice" ]]; then
        return 0
    fi
    
    source /tmp/.gz302-llm-choice
    if [[ "${MIGRATE_MODELS:-false}" != "true" ]]; then
        return 0
    fi
    
    local primary_user
    primary_user=$(get_real_user)
    
    if [[ "$primary_user" == "root" ]]; then
        warning "Running as root - models will be migrated to /root/models"
    fi
    
    info "Migrating Ollama models to llama.cpp format..."
    
    # Create models directory for llama.cpp
    local models_dest="/home/$primary_user/models"
    if [[ "$primary_user" == "root" ]]; then
        models_dest="/root/models"
    fi
    
    mkdir -p "$models_dest"
    
    # Check common Ollama model locations
    local ollama_model_dirs=(
        "/home/$primary_user/.ollama/models"
        "/usr/share/ollama/.ollama/models"
        "/root/.ollama/models"
    )
    
    local migrated_count=0
    
    for model_dir in "${ollama_model_dirs[@]}"; do
        if [[ ! -d "$model_dir" ]]; then
            continue
        fi
        
        info "Checking $model_dir for models..."
        
        # Find GGUF files (llama.cpp native format)
        while IFS= read -r -d '' model_file; do
            local model_name
            model_name=$(basename "$model_file")
            local dest_file="$models_dest/$model_name"
            
            if [[ ! -f "$dest_file" ]]; then
                info "Copying $model_name..."
                cp "$model_file" "$dest_file"
                ((migrated_count++))
            else
                info "Skipping $model_name (already exists)"
            fi
        done < <(find "$model_dir" -type f \( -name "*.gguf" -o -name "*.bin" \) -print0 2>/dev/null)
        
        # Also look for model manifests/blobs (Ollama's internal format)
        if [[ -d "$model_dir/manifests" ]] && [[ -d "$model_dir/blobs" ]]; then
            info "Found Ollama manifest/blob structure in $model_dir"
            info "Note: These are in Ollama's internal format and need conversion."
            info "To convert: Use 'ollama pull' with the old installation to export,"
            info "            or download GGUF versions directly from HuggingFace."
            
            # List available models for user reference
            if [[ -d "$model_dir/manifests/registry.ollama.ai" ]]; then
                info "Available Ollama models found:"
                find "$model_dir/manifests/registry.ollama.ai" -type f 2>/dev/null | while read -r manifest; do
                    local model_name
                    model_name=$(echo "$manifest" | sed 's|.*/registry.ollama.ai/||' | sed 's|/|:|')
                    echo "    - $model_name"
                done
            fi
        fi
    done
    
    # Set ownership
    if [[ "$primary_user" != "root" ]]; then
        chown -R "$primary_user:$(id -gn "$primary_user")" "$models_dest"
    fi
    
    if [[ $migrated_count -gt 0 ]]; then
        success "Migrated $migrated_count model file(s) to $models_dest"
        info "Use llama.cpp with: llama-cli -m $models_dest/<model-name>"
    else
        warning "No compatible model files found to migrate"
        info "Ollama uses an internal format. To use models with llama.cpp:"
        echo "  1. Download GGUF models from HuggingFace (recommended)"
        echo "  2. Or convert Ollama models using conversion tools"
        echo "  3. Place GGUF files in: $models_dest"
    fi
    
    info "Your original Ollama data remains in ~/.ollama (safe to remove manually)"
}

# Main migration function
main() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Please use sudo."
        exit 1
    fi
    
    echo
    echo "============================================================"
    echo "  GZ302 Path Migration to Standard Defaults"
    echo "============================================================"
    echo
    
    info "Checking for old custom paths..."
    
    if ! detect_old_paths; then
        success "No old custom paths detected. Migration not needed."
        exit 0
    fi
    
    echo
    warning "IMPORTANT: Custom paths detected from previous installation!"
    echo
    echo "The GZ302 setup scripts have been updated to use standard default"
    echo "paths instead of custom paths for better troubleshooting and"
    echo "compatibility. This migration will move your existing installations"
    echo "to the new standard locations."
    echo
    echo "Changes that will be made:"
    
    # Show what will be migrated
    if [[ -d "/opt/llama.cpp" ]]; then
        echo "  • llama.cpp: /opt/llama.cpp → /usr/local/bin"
    fi
    
    local primary_user
    primary_user=$(get_real_user)
    if [[ "$primary_user" != "root" ]]; then
        if [[ -d "/home/$primary_user/.gz302-llm-venv" ]]; then
            echo "  • Python venv: ~/.gz302-llm-venv → ~/llm-venv"
        fi
        
        if [[ -d "/home/$primary_user/.local/share/gz302/frontends" ]]; then
            echo "  • Frontend tools: ~/.local/share/gz302/frontends/<name> → ~/<name>"
        fi
    fi
    
    echo
    echo "Your existing installations and configurations will be preserved."
    echo "Old directories will be cleaned up after successful migration."
    echo
    
    # Handle Ollama migration first (user choice affects whether llama.cpp gets installed)
    handle_ollama_migration
    
    # Ask for confirmation if running in interactive mode
    if [[ -t 0 ]]; then
        echo
        read -r -p "Proceed with migration to standard default paths? [Y/n]: " response
        response="${response,,}" # to lowercase
        if [[ -n "$response" && "$response" != "y" && "$response" != "yes" ]]; then
            warning "Migration cancelled by user."
            echo "Note: You can run this script manually later: sudo ./gz302-migrate-paths.sh"
            # Clean up choice file
            rm -f /tmp/.gz302-llm-choice
            exit 0
        fi
    else
        info "Non-interactive mode: proceeding with migration automatically"
    fi
    
    echo
    info "Beginning migration..."
    echo
    
    # Run migrations
    migrate_llama_cpp
    migrate_python_venv
    migrate_frontends
    migrate_ollama_models
    
    echo
    success "Path migration complete!"
    echo
    info "All paths now use standard default locations:"
    echo "  - llama.cpp binaries: /usr/local/bin/llama-*"
    echo "  - Python virtual environment: ~/llm-venv"
    echo "  - Frontend tools (if installed): ~/<tool-name>"
    echo "  - LLM models (if migrated): ~/models/"
    echo
    info "These are standard default paths used by most Linux installations."
    echo "This makes troubleshooting easier and follows best practices."
    echo
}

main "$@"
