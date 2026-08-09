# Real-image fixtures

These files are copies of camera originals selected for integration testing.
The original files under `~/Pictures/2026` are never modified.

| File | Purpose |
| --- | --- |
| `IMG_5244.HEIC` | iPhone 15 Pro, Display P3 adaptive HDR with gain maps, orientation 6 |
| `real-sdr-8bit.heif` | 6000×4000, 8-bit sRGB SDR, orientation 1 |
| `real-sdr-10bit-display-p3.heif` | Same scene, 10-bit Display P3 SDR |
| `real-orientation-8.heif` | 6000×4000, 8-bit sRGB SDR, orientation 8 |

The `.heif` extension deliberately differs from the converter's `.heic`
output extension, so each fixture can be converted without overwriting its
input. The files contain camera and capture-date metadata but no GPS location,
owner name, artist, copyright, or camera serial number.

No HDR image was found under `~/Pictures/2026`, but `IMG_5244.HEIC` was supplied
separately. In a normal unsandboxed ImageIO environment it has a content
headroom of about 3.56 and contains HDR/ISO gain maps. Deterministic generated
HDR images remain in the suite so HDR behavior is also tested independently of
this camera original.
