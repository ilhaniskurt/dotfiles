#!/usr/bin/env bash

# Define constants for script
LOG_FILE="${HOME}/Library/Logs/dotfiles_setup.log"
GITHUB_USER="ilhaniskurt"
GITHUB_REPO="dotfiles"
USER_NAME="İlhan Yavuz İskurt"
USER_EMAIL="85507446+ilhaniskurt@users.noreply.github.com"
DOTFILES_DIR="${HOME}/.local/opt/${GITHUB_REPO}"
SSH_KEY_PATH="${HOME}/.ssh/id_ed25519"


# Log message with timestamp (Silent to console)
log_message() {
    local type=$1
    local message=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$type] $message" >> "${LOG_FILE}"
}

# Print and log process message
process() {
    log_message "PROCESSING" "$1"
    printf "$(tput setaf 6)Processing: %s...$(tput sgr0)\n" "$1"
}

# Print and log success message
success() {
    log_message "SUCCESS" "$1"
    printf "$(tput setaf 2)✓ Success:$(tput sgr0) %s\n" "$1"
}

# Print and log warning message
warning() {
    log_message "WARNING" "$1"
    printf "$(tput setaf 3)⚠ Warning:$(tput sgr0) %s\n" "$1"
}

# Download and extract dotfiles repository
download_dotfiles() {
    process "Creating directory at ${DOTFILES_DIR} and setting permissions"
    mkdir -p "${DOTFILES_DIR}"

    process "Downloading repository to /tmp directory"
    curl -#fLo /tmp/${GITHUB_REPO}.tar.gz "https://github.com/${GITHUB_USER}/${GITHUB_REPO}/tarball/main"

    process "Extracting files to ${DOTFILES_DIR}"
    tar -zxf /tmp/${GITHUB_REPO}.tar.gz --strip-components 1 -C "${DOTFILES_DIR}"

    process "Removing tarball from /tmp directory"
    rm -rf /tmp/${GITHUB_REPO}.tar.gz

    if [[ $? -eq 0 ]]; then
        success "Repository downloaded and extracted to ${DOTFILES_DIR}"
    else
        warning "Failed to download or extract repository."
    fi
}

# Create symbolic links for dotfiles
link_dotfiles() {
    if [[ -f "${DOTFILES_DIR}/opt/files" ]]; then
        process "Symlinking dotfiles from ${DOTFILES_DIR}/opt/files"

        while IFS= read -r line || [[ -n "$line" ]]; do
            IFS='->' read -r src target <<< "${line/->/-}"
            src="${DOTFILES_DIR}/${src}"
            target="${HOME}/${target}"
            process "Linking ${src} to ${target}"
            mkdir -p "$(dirname "$target")"
            ln -fs "$src" "$target"
        done < "${DOTFILES_DIR}/opt/files"

        success "Dotfiles linked successfully."
    else
        warning "${DOTFILES_DIR}/opt/files not found."
    fi
}

# Install Homebrew and run initial setup
install_homebrew() {
    process "Installing Homebrew"
    export PATH=/opt/homebrew/bin:$PATH
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    process "Running brew doctor"
    brew doctor

    if [[ $? -eq 0 ]]; then
        success "Homebrew installed and ready"
    else
        warning "Homebrew installation or setup failed."
    fi

    process "Running brew bundle"
    brew bundle --file "${DOTFILES_DIR}/opt/Brewfile"
    
    if [[ $? -eq 0 ]]; then
        success "Brew bundle completed successfully"
    else
        warning "Brew bundle encountered issues."
    fi
}

# Configure Git authorship
setup_git_authorship() {
    local gitUserName=$(git config --global user.name)
    local gitUserEmail=$(git config --global user.email)
    local changesMade=false

    if [[ -z "$gitUserName" ]]; then
        if [[ -n "$USER_NAME" ]]; then
            git config --global user.name "$USER_NAME"
            process "Git user name set to '$USER_NAME'"
            changesMade=true
        else
            warning "Git user name not set and 'USER_NAME' variable is empty. Please set it manually."
        fi
    else
        process "Git user name is already set to '$gitUserName'. No changes made."
    fi

    if [[ -z "$gitUserEmail" ]]; then
        if [[ -n "$USER_EMAIL" ]]; then
            git config --global user.email "$USER_EMAIL"
            process "Git user email set to '$USER_EMAIL'"
            changesMade=true
        else
            warning "Git user email not set and 'USER_EMAIL' variable is empty. Please set it manually."
        fi
    else
        process "Git user email is already set to '$gitUserEmail'. No changes made."
    fi

    if [[ "$changesMade" = true ]]; then
        success "Git configuration updated successfully."
    else
        success "No changes have been made to git config"
    fi
}

setup_ssh() {
    process "Setting up ssh"
    # Generate SSH key, replacing if necessary
    if [ -f "$SSH_KEY_PATH" ]; then
        process "SSH key already exists at ${SSH_KEY_PATH}."
        read -rp "Do you want to overwrite it? [y/N]: " overwrite
        if [[ $overwrite =~ ^[Yy]$ ]]; then
            # Create the SSH key, overwriting any existing keys
            ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$SSH_KEY_PATH" -N ""
            success "New SSH key generated."
        else
            success "Using existing SSH key."
        fi
    else
        # Create the SSH key if it doesn't exist
        ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$SSH_KEY_PATH" -N ""
    fi

    # Start the ssh-agent in the background
    eval "$(ssh-agent -s)"

    # Automatically load keys into the ssh-agent and store passwords in your keychain
    echo "Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ${SSH_KEY_PATH}" > "${HOME}/.ssh/config"

    # Add the SSH key to the ssh-agent
    ssh-add --apple-use-keychain "$SSH_KEY_PATH"

    # Copy the SSH public key to the clipboard
    pbcopy < "${SSH_KEY_PATH}.pub"

    success "SSH public key copied to clipboard."
}


install_vscode_extensions() {

    process "Searching for extensions list for vscode"
    if [[ -f "${DOTFILES_DIR}/configs/.vscode_extensions.txt" ]]; then
        process "Installing vscode extensions from ${DOTFILES_DIR}/configs/.vscode_extensions.txt"

        cat "${DOTFILES_DIR}/configs/.vscode_extensions.txt" | xargs -L 1 code --install-extension

        success "Vscode extensions installed successfully."
    else
        warning "${DOTFILES_DIR}/configs/.vscode_extensions.txt not found"
    fi
}

custom_jobs() {
    install_vscode_extensions
}

# Main installation function
install() {
    log_message "INFO" "Starting installation process"
    download_dotfiles
    install_homebrew
    link_dotfiles
    setup_git_authorship
    setup_ssh
    custom_jobs
    success "Installation process completed successfully."
}

install
