# Local-only IGME 2025 input — 25 October 2026

The exact file `01_raw_data/1.5_DUIO/UN IGME 2025.csv` exceeds GitHub's
100 MB regular-file limit. It is now ignored and excluded from the unpublished
history of `dev_SPI_2025`. Other IGME vintages remain tracked.

The local CSV was retained without changes, with SHA-256:

```text
6423ac3853078f1e045c17e298e4adef33802173a856f3f231db36fa7a842a5e
```

A fresh clone must obtain this manual source file separately and place it at
the exact path above before running the configured 202611 estimation. The
local pipeline still uses the existing file; no estimates were rerun.

The rewrite preserves all 58 unpublished commits, their messages, author and
committer metadata, and every other file in each commit. Published history
and other local branches were unchanged. The original history remains in
the local backup branch
`backup/dev_SPI_2025-before-file-exclusion-20261025`, which is not pushed.

The [commit map](git-history-rewrite-map-2026-10-25.csv) links each original
commit ID to its rewritten ID. Historical reports retain their original
commit IDs; use this map when following those references in the published
branch. The executable replication and attribution baseline was updated
from `8df2865` to `25b534706ff6`, whose tracked contents differ only by the
excluded CSV.
