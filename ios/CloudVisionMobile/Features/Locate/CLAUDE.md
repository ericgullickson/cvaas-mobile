# Locate/

F1 Endpoint Locator. Pure REST against `arista.endpointlocation.v1`.

## Files

| File | What | When to read |
|------|------|--------------|
| `EndpointLocationModels.swift` | Codable models matching the proto: `EndpointRecord` (renamed to avoid collision with `inventory.v1.Device`), `Location`, `Identifier`, plus tolerant enums (`Likelihood`, `MacType`, `IdentifierType`, `IdentifierSource`, `Explanation`, `DeviceType`, `DeviceStatus`) | Adding fields, adapting to API changes, changing enum mappings |
| `EndpointLocationService.swift` | `find(searchTerm:)` wraps `GET /api/resources/endpointlocation/v1/EndpointLocation?key.searchTerm=…` and flattens the nested response into a view-friendly `LocateResults` | Changing query parameters, adding filters, rewriting result flattening |
| `LocateView.swift` | Main search UI: text field, results list, recents, loading/empty/error states | Modifying search UX, adding scan camera (CAP-1.4 stretch), changing state transitions |
| `LocateResultRow.swift` | Card for one matched endpoint: identifiers, locations, likelihood badge, explanation chips | Tuning row layout, adding fields, changing badge colors |
