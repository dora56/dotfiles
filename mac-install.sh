#! /bin/bash
set -e

actions=${GITHUB_ACTIONS:-false}

echo "-----------------------------"
echo "-         Homebrew          -"
echo "-----------------------------"
if [ -z "$(ls /opt/homebrew/bin)" ]; then
    echo "Download Homebrew."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi skip."
    chezmoi update
else
    echo "chezmoi setup Start..."
    brew install chezmoi
    brew install --cask 1password 1password-cli
    if [ "$actions" = false ]; then
        printf "\033[33mPlease setup 1Password and CLI.\033[0m\n"
        printf "\033[33mIf you have completed the setup, press the Enter key.\033[0m\n"
        read -r
    fi
    chezmoi init dora56 --apply
    echo "dotfiles clone finish."
fi

if [ "$actions" = true ]; then
    echo "Test install..."
    brew bundle --file ~/tests/Brewfile
else
echo "Brewfiles install..."
    brew bundle --file ~/Brewfile
fi

echo "-----------------------------"
echo "-            dir            -"
echo "-----------------------------"

if [ -z "$(ls "$HOME"/Development)" ]; then
    echo "mkdir Development"
    mkdir -p ~/Development
fi

if [ -z "$(ls "$HOME"/.cache)" ]; then
    echo "mkdir .cache"
    mkdir -p ~/.cache
fi

if [ -z "$(ls "$HOME"/.zfunc)" ]; then
    echo "mkdir .zfunc"
    mkdir -p ~/.cache
fi


if [ -z "$(ls "$HOME"/.cargo)" ]; then
    echo "-----------------------------"
    echo "-           Rust            -"
    echo "-----------------------------"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh #DevSkim: ignore DS440000 until 2023-03-13 
fi

if [ -z "$(ls "$HOME"/.sdkman)" ]; then
    echo "-----------------------------"
    echo "-          SDKMAN            -"
    echo "-----------------------------"
    curl -s "https://get.sdkman.io" | bash
fi

echo "-----------------------------"
echo "-            asdf           -"
echo "-----------------------------"
if command -v asdf >/dev/null 2>&1; then
    echo ""
else
    /bin/bash -c "$(brew --prefix asdf)/libexec/asdf.sh"
fi

asdf_plugins="$HOME/.scripts/asdf-plugins.json"
if [ "$actions" = true ]; then
    asdf_plugins=~/tests/asdf-plugins.json
fi
plugins=$(jq '.plugins[].name' "$asdf_plugins" | tr -d '"')

for plugin in $plugins; do
    version=$(jq ".plugins[] | select(.name==\"$plugin\") | .version" "$asdf_plugins" | tr -d '"')
    if [ "$(asdf plugin list | grep "$plugin")" != "$plugin" ]; then
        plugin_install="asdf plugin add $plugin"
        $plugin_install
    fi
    asdf plugin update --all
    install_command="asdf install $plugin $version"
    $install_command
    local_command="asdf local $plugin $version"
    $local_command
done

echo "-----------------------------"
echo "-            rye            -"
echo "-----------------------------"
if command -v rye >/dev/null 2>&1; then
    echo ""
else
    curl -sSf https://rye-up.com/get | bash
fi

printf "\033[32mCompleted.\033[m\n"
