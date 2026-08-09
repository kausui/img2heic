# Expected conversion outputs

These files were generated on 2026-08-09 by the release build of `img2heic`
using the default compression quality (`0.8`). They are retained for manual
inspection and comparison with the corresponding files in
`Tests/img2heicTests/Fixtures`.

| File | Expected characteristics |
| --- | --- |
| `real-sdr-8bit.expected.heic` | 6000×4000, 8-bit, sRGB, orientation 1, SDR |
| `real-sdr-10bit-display-p3.expected.heic` | 6000×4000, 10-bit, Display P3, orientation 1, SDR |
| `real-orientation-8.expected.heic` | 6000×4000, 8-bit, sRGB, orientation 8, SDR |
| `iphone-hdr-gainmap.expected.heic` | 4032×3024, Display P3, orientation 6, HDR headroom about 3.56, gain map present |

SHA-256 at generation time:

```text
25f7af088e2e4f0522551943ecf6d5ccf429cb183dcff6d9ca6d5d93cb4bcab1  iphone-hdr-gainmap.expected.heic
ffd6f123891d50da073aff796304c1dfaec5edbbe419b9fb8d798eddc021a72f  real-orientation-8.expected.heic
7364eacd3f850eb995544e359a3a1b65ca6440bc472b3de2df3579052dba1473  real-sdr-10bit-display-p3.expected.heic
0bb24a0f1e2f1ac8f123efab77b48d7ee0c6aefde2015430de097372baf31ddd  real-sdr-8bit.expected.heic
```

These are reference artifacts, not byte-for-byte golden test inputs. HEIC
encoder output may differ across macOS releases and hardware even when the
decoded image and metadata are equivalent. Automated tests therefore validate
decoded properties rather than these hashes.
