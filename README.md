# Auto-agenda 2026

Gedeelde agenda voor de auto van Boris, Job en Mama.

- Agenda van 2026 met per dag 3 dagdelen: ochtend, middag, avond
- Dagdelen aanvragen, met een opmerking per dagdeel en een algemene opmerking
- Goedgekeurd als **beide** anderen akkoord geven; één afwijzing = afgewezen
- Meldingen-tab met badge, live bijgewerkt
- Opslag in Supabase, dubbele boekingen worden door de database geweigerd

## Installatie (±5 minuten)

1. Maak een gratis project op https://supabase.com (regio: Frankfurt/EU).
2. Ga naar **SQL Editor → New query**, plak de inhoud van `supabase/schema.sql` en klik **Run**.
3. Ga naar **Project Settings → API** en kopieer de **Project URL** en de **anon public key**.
4. Vul die in `config.js` in.
5. Zet de map in GitHub en koppel de repo aan Vercel (Framework: *Other*, geen build command).

Zonder ingevulde `config.js` draait de site in demo-modus (niets wordt bewaard).

## Bestanden
- `index.html` — de hele app
- `config.js` — Supabase URL + anon key
- `supabase/schema.sql` — tabellen, controles en rechten
- `favicon.png`, `favicon.ico`, `apple-touch-icon.png` — icoon

## Let op
Er is geen echte login: wie de link heeft, kan als iedereen een aanvraag doen of stemmen.
Deel de link dus alleen met het gezin. Pushmeldingen komen in een volgende stap.
