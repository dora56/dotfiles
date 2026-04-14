#!/usr/bin/env bash
set -u

if [[ "$(uname -s)" != "Darwin" ]]; then
  exit 0
fi

warnings=0

run_step() {
  local description="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    printf '[OK] %s\n' "${description}"
  else
    printf '[WARN] %s\n' "${description}" >&2
    warnings=1
  fi
}

run_step "Expand save panel" defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
run_step "Expand print panel" defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
run_step "Save documents to disk by default" defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
run_step "Disable smart quotes" defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
run_step "Disable smart dashes" defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
run_step "Trackpad haptic threshold" defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 0
run_step "Trackpad actuation strength" defaults write com.apple.AppleMultitouchTrackpad ActuationStrength -int 0
run_step "Enable trackpad right click" defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
run_step "Enable Apple trackpad right click" defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
run_step "Set secondary click corner" defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
run_step "Disable press and hold" defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
run_step "Set initial key repeat" defaults write NSGlobalDomain InitialKeyRepeat -int 20
run_step "Set key repeat" defaults write NSGlobalDomain KeyRepeat -int 1
run_step "Disable auto-correct" defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
run_step "Save screenshots to Downloads" defaults write com.apple.screencapture location -string "${HOME}/Downloads"
run_step "Use PNG screenshots" defaults write com.apple.screencapture type -string png
run_step "Disable screenshot shadow" defaults write com.apple.screencapture disable-shadow -bool true
run_step "Show hidden files in Finder" defaults write com.apple.finder AppleShowAllFiles -bool true
run_step "Show all filename extensions" defaults write NSGlobalDomain AppleShowAllExtensions -bool true
run_step "Show Finder status bar" defaults write com.apple.finder ShowStatusBar -bool true
run_step "Allow Quick Look text selection" defaults write com.apple.finder QLEnableTextSelection -bool true
run_step "Show POSIX path in Finder title" defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
run_step "Use current folder search scope" defaults write com.apple.finder FXDefaultSearchScope -string SCcf
run_step "Disable extension change warning" defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
run_step "Avoid .DS_Store on network volumes" defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
run_step "Unhide Library" chflags nohidden "${HOME}/Library"
run_step "Auto-hide Dock" defaults write com.apple.dock autohide -bool true
run_step "Set Dock icon size" defaults write com.apple.dock tilesize -int 30
run_step "Speed up Mission Control" defaults write com.apple.dock expose-animation-duration -float 0.15
run_step "Dim hidden Dock apps" defaults write com.apple.dock showhidden -bool true
run_step "Reduce transparency" defaults write com.apple.universalaccess reduceTransparency -bool true
run_step "Set bottom-right hot corner" defaults write com.apple.dock wvous-br-corner -int 2
run_step "Set top-right hot corner" defaults write com.apple.dock wvous-tr-corner -int 10
run_step "Set bottom-left hot corner" defaults write com.apple.dock wvous-bl-corner -int 4
run_step "Enable Safari Develop menu" defaults write com.apple.Safari IncludeDevelopMenu -bool true
run_step "Enable Safari Web Inspector" defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
run_step "Enable global Web Inspector" defaults write NSGlobalDomain WebKitDeveloperExtras -bool true
run_step "Copy Mail addresses without names" defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false
run_step "Show Activity Monitor main window" defaults write com.apple.ActivityMonitor OpenMainWindow -bool true
run_step "Show all Activity Monitor processes" defaults write com.apple.ActivityMonitor ShowCategory -int 0
run_step "Disable smart quotes in Messages" defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add automaticQuoteSubstitutionEnabled -bool false
run_step "Disable spell checking in Messages" defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add continuousSpellCheckingEnabled -bool false

killall Dock Finder SystemUIServer Activity\ Monitor >/dev/null 2>&1 || true

if [[ "${warnings}" -eq 1 ]]; then
  printf '[WARN] macOS defaults completed with one or more skipped settings.\n' >&2
else
  printf '[OK] macOS defaults completed.\n'
fi
