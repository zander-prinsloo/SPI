# Data Sources

<!-- cg:auto:datasets -->
Sources are registered in `config/source_registry.R` and stored under
`01_raw_data/`. The [runtime inventory](../docs/source-runtime-audit.md)
identifies acquisition for PIP, World Bank snapshots, JMP, OECD/UN SDG,
NADA, censuses/surveys, and annual standards reviews. The
[user guide](../docs/user-guide.md#44-detailed-source-instructions) gives
filenames and manual actions.

Raw/cache responses, normalized artifacts, manifests, and provenance records
serve different purposes. Source attestations bind analyst acceptance to
actual file bytes; file presence or modification time is not source approval.
<!-- cg:auto:end -->

<!-- cg:auto:vintages -->
202611 is the planned update identifier; its reference year is 2025. The
previous approved SPI vintage is 202511, reference year 2024.
`01_raw_data/previous_vintages/` holds previous SPI indicator/index outputs
and their approved hash manifest, not every raw source release.

D1.5, D4.1, and D4.2 history is refreshed; changes in frozen dimensions require
explicit approval. ODIN is provisional for the retained review snapshot and
requires an approved official release record before finalization. See the
[ODIN guide](../docs/odin-delayed-update.md).
<!-- cg:auto:end -->

<!-- cg:auto:access -->
Most sources are public. The D4.1 catalogue refresh also uses the World Bank
internal microdata library; some manual material requires institutional access.
The open-data principle and retention of the internal source remain explicit
review considerations.

The exact `UN IGME 2025.csv` is a local-only manual input. Designated review
CSVs/evidence are versioned, while bulk recovered runs/probes/logs are ignored
inside the repo. A fresh clone therefore requires both the restored R
environment and the documented manual files; `run_downloads = FALSE` does
not guarantee an offline run.
<!-- cg:auto:end -->

← [Home](README.md)