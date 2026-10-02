# Game Extractor integration

Universal Extractor can use **Game Extractor Basic** as an optional, low-priority fallback for game archives.

## Why it is optional

Game Extractor has very broad game-format coverage, but its normal Windows package is large because it includes its own Java runtime and related libraries. Bundling the complete package in every UniExtract release would substantially increase the download size even for users who never extract game archives.

The integration therefore lives under:

```text
bin\GameExtractor\
```

and is used only when the expected files are present.

Required entry points:

```text
bin\GameExtractor\GameExtractor.jar
bin\GameExtractor\jre\bin\java.exe
```

The easiest installation method is UniExtract's Plugin Manager. You can also download the public Basic `extract.zip` from the official Game Extractor GitHub releases and extract it into `bin\GameExtractor\`.

## Routing order

Game Extractor is deliberately not a primary detector.

UniExtract first keeps its existing routes, including dedicated installer/archive handlers, GARbro, QuickBMS, extension-specific handlers and the generic 7-Zip probe. Game Extractor is tried after those routes fail and before the final Unix-file/strict fallback stages.

This keeps ordinary archive extraction fast and avoids Game Extractor overriding a more specific extractor.

## Command used

UniExtract invokes the Basic package's bundled Java runtime and command-line interface:

```text
jre\bin\java.exe -Xmx1024m -jar GameExtractor.jar -extract -input "<archive>" -output "<directory>"
```

A run is only accepted as successful when Game Extractor reports `Finished extracting files` **and** UniExtract can see real output in the destination directory.

## Coverage reviewed

The public Game Extractor v3.16.0008 source tree contains **1,957 archive plugin source files**. The corresponding 3.16-generation archive plugin set examined for this integration declared **1,058 distinct file extensions**.

That does not mean every one is unique to Game Extractor: there is substantial overlap with 7-Zip, GARbro and QuickBMS. The value of the fallback is the long tail of game-specific archive variants and per-game parsers that are impractical to reproduce as individual AutoIt routes.

## Licensing boundary

Game Extractor's public repository describes the **Basic Version** source as GPLv2. The paid **Full Version** is explicitly separate and its code is not covered by that public GPLv2 source release.

For that reason:

- UniExtract does not bundle files taken from a purchased Full Version.
- The Plugin Manager points users at the public Basic release.
- Proprietary/native files found inside a Full installation are not copied into this repository.
- In particular, do not lift Oodle DLLs or other third-party binaries out of a purchased Full package without separately establishing redistribution rights.

The upstream package also contains third-party components with their own licences. Keep the upstream licence material intact when redistributing an unmodified Basic package.

## Updating

When Game Extractor publishes a new Basic release, the fallback does not normally need source changes because it targets the stable command-line interface and expected package layout. Retest the CLI success marker and extraction behavior before changing the recommended version.
