# blueprint

Turn your app icon into a blueprint version, like Xcode's icon, for your debug builds.

<p align="center">
  <img src="docs/icon.png" width="160" alt="App icon">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/debug-icon.png" width="160" alt="Blueprint debug icon">
</p>

## Install

With [Homebrew](https://brew.sh), from [MustafaNatur/homebrew-tap](https://github.com/MustafaNatur/homebrew-tap):

```bash
brew install mustafanatur/tap/blueprint
```

Or from source:

```bash
git clone https://github.com/MustafaNatur/blueprint.git
cd blueprint
make install
```

This puts `blueprint` in `~/.local/bin`. Make sure that folder is on your `PATH`.

Requires macOS 14+ and Xcode 26+.

## Use

Pass the path to your `.icon` file:

```bash
blueprint path/to/AppIcon.icon
```

It draws `AppIconDebug.icon` in the folder you ran the command from and opens it in Icon Composer.

## Options

| Option | Default | |
|---|---|---|
| `-o`, `--output` | `<Name>Debug.icon` in the current folder | Where to save the blueprint. |
| `--color` | `#0AC2FC,#10A3FA,#1A6FFB` | Background colors, top to bottom. |
| `--line-width` | `9` | Outline width. |
| `--no-grid` | | Leaves out the grid lines. |
| `--no-open` | | Doesn't open Icon Composer. |

## Good to know

- Your icon must be an Icon Composer `.icon` file. Classic `.appiconset` icons aren't supported.
- Running `blueprint` again replaces the blueprint it drew before. It never overwrites any other icon.
- To use the blueprint for Debug builds, set **Primary App Icon Set Name** (`ASSETCATALOG_COMPILER_APPICON_NAME`) to `AppIconDebug` for the Debug configuration in Xcode.
