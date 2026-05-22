EXCLUDED_BUNDLES = {
    # Privacy-sensitive
    "com.apple.keychainaccess",
    "com.1password.1password",
    "com.agilebits.onepassword7",
    "com.bitwarden.desktop",
    # System shells with no AX-queryable main window — capture would always
    # return empty and the focus event is usually a transient handoff.
    "com.apple.dock",
    "com.apple.WindowManager",
    "com.apple.controlcenter",
    "com.apple.notificationcenterui",
    "com.apple.systemuiserver",
    "com.apple.loginwindow",
    "com.apple.spotlight",
    # Daemon's own interpreter — focus events fire on it during handoffs.
    "org.python.python",
    # Low-signal
    "com.apple.finder",
}
