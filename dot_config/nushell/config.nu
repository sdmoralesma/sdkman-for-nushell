# config.nu
#
# Installed by:
# version = "0.102.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# This file is loaded after env.nu and before login.nu

# SDKMAN!
$env.SDKMAN_DIR = (brew --prefix sdkman-cli | path parse | path join 'libexec')

# -----------------------------------------------------------------------------
# Nushell Modules & Overlays
# -----------------------------------------------------------------------------

# SDKMAN
const sdkman = ($nu.default-config-dir | path join 'overlays' | path join 'sdkman.nu')
overlay use $sdkman
