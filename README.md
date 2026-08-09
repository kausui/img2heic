# img2heic

`img2heic` is a macOS command-line tool that converts an image file to HEIC
while preserving its color space, compatible metadata, and dynamic range.

## Features

- Converts ordinary SDR images to 8-bit HEIC.
- Converts high-bit-depth SDR images to 10-bit HEIC.
- Preserves an existing HDR/ISO gain map when present.
- Converts PQ, HLG, and other HDR input to an SDR-compatible HEIC with a gain map.
- Preserves compatible ICC, EXIF, capture date, GPS, and orientation metadata.
- Never overwrites the input or an existing output file.

SDR input is not artificially expanded to HDR.

## Requirements

- macOS 15.0 or later
- Swift 6.0 or later

## Build

```sh
swift build -c release
```

The executable is generated under `.build/<architecture>-apple-macosx/release/`.
You can also locate it with:

```sh
swift build -c release --show-bin-path
```

## Usage

```text
img2heic <input> [-c|--compress <0...1>] [-o|--output <path>] [--verbose]
```

Convert an image using the default compression quality (`0.8`):

```sh
./img2heic path-to-image-file
```

Choose a compression quality:

```sh
./img2heic path-to-image-file --compress 0.9
```

Choose an output file or an existing output directory:

```sh
./img2heic path-to-image-file --output converted.heic
./img2heic path-to-image-file --output path-to-output-directory
```

Show the detected bit depth, color space, HDR headroom, gain-map status, and
selected conversion mode:

```sh
./img2heic path-to-image-file --verbose
```

Compression quality must be a finite number from `0` to `1`. A value of `0`
produces the smallest output; `1` produces the highest image quality supported
by the encoder.

By default, the output is written beside the input with a `.heic` extension.
For example, `photo.jpg` becomes `photo.heic`. An output file path without an
extension receives the `.heic` extension automatically. Output directories must
already exist. Conversion stops with an error if the output already exists.

## Test

```sh
swift test
```

Real camera inputs are stored under `Tests/img2heicTests/Fixtures`. Their
retained conversion results for manual comparison are stored under
`Tests/Expected`.

## License

MIT. See [LICENSE](LICENSE).
