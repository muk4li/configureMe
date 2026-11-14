# Linux-Plan-v1-Fixtures (synthetisch)

Alle Dateien hier sind **synthetisch** und nur für Tests gedacht. `catalog.synthetic.json` entspricht `linux/catalog.json`, enthält aber erfundene Docker-Pins (`…~synthetic`); kein Runner darf damit installieren. Die Pläne binden per `catalogRevision` an diesen synthetischen Katalog.

- `valid-*.json`: müssen angenommen werden.
- `invalid-*.json`: müssen abgelehnt werden; erwarteter Fehlercode in `expected-errors.json`.

Neu erzeugen nur bewusst; Bytes sind über `.gitattributes` auf LF festgelegt.
