# SDKMAN! for Nushell

A lightweight Nushell overlay that enables full SDKMAN! support inside Nushell.

It makes the `sdk` command available in Nushell (including auto-completion) and adds binaries from installed SDKs to your `PATH`.

> ⚠️ This project is in early development and might have bugs - Please report!


## 🚀 Features
- Activate SDKMAN! inside Nushell
- Load environment variables via export-env
- Works with overlay use or simple use
- No external dependencies beyond SDKMAN installation
- Clean and reversible overlay (unload anytime)

## 📦 Installation

First, install [SDKMAN](https://sdkman.io) either through bash:

```sh
$ curl -s "https://get.sdkman.io" | bash
```
or [sdkman-homebrew-tap](https://github.com/sdkman/homebrew-tap):
```sh
$ brew tap sdkman/tap
$ brew install sdkman-cli
```

Then, clone the overlay file to your nushell configuration directory:
```sh
curl -L https://raw.githubusercontent.com/sdmoralesma/sdkman-for-nushell/main/dot_config/nushell/overlays/sdkman.nu \
    -o ($nu.default-config-dir + "/overlays/sdkman.nu")
```

## 🔭 Development
Then clone this repository:
```sh
git clone https://github.com/sdmoralesma/sdkman-for-nushell.git \
    ~/.config/nushell/sdkman-for-nushell
```

## 🧩 Enabling the overlay

It's recommended to add to your nushshell `config.nu` file:

```
overlay use ~/.config/nushell/sdkman-for-nushell/sdkman.nu
```

Alternatively (simpler, but not unloadable)
```
use ~/.config/nushell/sdkman-for-nushell/sdkman.nu
```

## 🛠 Usage

After loading the overlay, all SDKMAN environment variables are activated.

You can now use sdk the same way as in Bash:
```sh
sdk list java
sdk install java 21.0.3-tem
sdk use java 21.0.3-tem
sdk current
```

## 🧹 Unloading the overlay

If you used overlay use, you can cleanly remove it:

```
overlay hide sdkman
```