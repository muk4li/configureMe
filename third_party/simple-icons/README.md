# Locally bundled product icons

Source: [Simple Icons 16.37.0](https://github.com/simple-icons/simple-icons/tree/16.37.0), downloaded from the npm registry as `simple-icons@16.37.0`. The archive SHA-512 was checked against registry integrity. No new npm dependency was added. See [provenance.json](provenance.json) for archive integrity, upstream source/guideline URLs, package mappings and SHA-256 of both original SVGs and extracted paths.

Only icons with explicit compatible license metadata were selected. We read the versioned [disclaimer](DISCLAIMER.md); **CC0 for the collection is not a license grant for every underlying brand asset**. No CDN/favicon lookup or external image URL is used at runtime.

| Package(s) | Asset / attribution | License retained here |
| --- | --- | --- |
| Git | Git logo by Jason Long, via Simple Icons; unchanged path; source https://git-scm.com/community/logos | [CC BY 3.0](CC-BY-3.0.txt); attribution retained; Simple Icons' vector adaptation |
| .NET 10 SDK | .NET brand icon via Simple Icons; original source/guideline commit recorded in provenance | [CC0 1.0](CC0-1.0.md) |
| GitHub Copilot Desktop / CLI | Shared GitHub Copilot brand symbol via Simple Icons, sourced from Primer Octicons; identifies the brand, not a distinct CLI/Desktop product logo | [MIT, GitHub Inc.](Primer-MIT.txt) plus [collection CC0](CC0-1.0.md) |

The three paths are extracted unchanged into `src/assets/product-icons.json`. Display colors use recorded brand colors; Copilot's black monochrome path uses the light foreground on the dark background. Brand names/trademarks remain with their owners; this is informational package identification, not endorsement. The collection does not supply reviewed current assets for every product, and missing/uncertain underlying licensing was not guessed.

VS Code, PowerShell, GitHub CLI, Node.js, Python, 7-Zip, Firefox, LibreOffice, OpenSSH and Teams therefore use an original neutral geometric package symbol. It is not presented as an official logo. The fallback is part of configureMe's own UI code, with no third-party asset or extra license dependency. Future/unknown IDs also receive this symbol.

Both variants are inline decorative SVGs with fixed 26×26 dimensions, no loading request, script, raw SVG HTML injection or external reference. Product name, checkbox state, dependency explanation and mode remain visible text. Icon failure/absence cannot replace those semantics or shift the card layout.

Updates must repeat source/license review and update provenance hashes/tests; never replace these assets with dynamic third-party images. Full standard license texts were read from SPDX license-list-data (CC BY 3.0) and primer/octicons (MIT); the versioned Simple Icons CC0/disclaimer are retained alongside them.
