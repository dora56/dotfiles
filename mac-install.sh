#! /bin/bash
set -e

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
    chezmoi init dora56 --apply
    echo "dotfiles clone finish."
fi

brew bundle --file ~/Brewfile

if [ -z "$(ls "$HOME"/.cargo)" ]; then
    echo "-----------------------------"
    echo "-           Rust            -"
    echo "-----------------------------"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh #DevSkim: ignore DS440000 until 2023-03-13 
fi

echo "-----------------------------"
echo "-            asdf           -"
echo "-----------------------------"
asdf_plugins="$HOME/.scripts/asdf-plugins.json"
plugins=$(jq '.plugins[].name' "$asdf_plugins" | tr -d '"')

for plugin in $plugins; do
    version=$(jq ".plugins[] | select(.name==\"$plugin\") | .version" "$asdf_plugins" | tr -d '"')
    if [ "$(asdf plugin list | grep "$plugin")" != "$plugin" ]; then
        plugin_install="asdf pulgin add $plugin"
        $plugin_install
    fi
    asdf plugin update --all
    install_command="asdf install $plugin $version"
    $install_command
    local_command="asdf local $plugin $version"
    $local_command
done

printf "\033[32mCompleted.\033[m\n"
