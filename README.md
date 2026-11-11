# Auto-agenda 2026

Gedeelde agenda voor de auto van Boris, Job en Mama.

- Agenda van 2026 met per dag 3 dagdelen: ochtend, middag, avond
- Aanvragen met opmerking per dagdeel; goedgekeurd als **beide** anderen akkoord zijn
- Opslag in Supabase, live bijgewerkt, dubbele boekingen geweigerd
- Pushmeldingen op je telefoon bij aanvraag, akkoord, afwijzing en intrekking

## 1. Supabase
1. SQL Editor → plak `supabase/schema.sql` → Run
2. Project Settings → API → kopieer Project URL + anon key naar `config.js`

## 2. Vercel
Zet de map in GitHub en importeer in Vercel (Framework: *Other*, geen build command).
Voeg onder **Settings → Environment Variables** toe:

| Naam | Waarde |
|---|---|
| `SUPABASE_URL` | je Project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Project Settings → API → *service_role* (geheim!) |
| `VAPID_PUBLIC_KEY` | dezelfde als `vapidPublicKey` in `config.js` |
| `VAPID_PRIVATE_KEY` | geheim, niet in GitHub zetten |
| `VAPID_SUBJECT` | `mailto:info@flyingimages.nl` |
| `NOTIFY_SECRET` | zelfgekozen geheime string |

Daarna **Redeploy**.

## 3. Pushmeldingen koppelen
SQL Editor → plak `supabase/push.sql`, vul onderaan je Vercel-URL en `NOTIFY_SECRET` in → Run.

## 4. Op de telefoon
- **iPhone (iOS 16.4+):** open de site in Safari → Deel → *Zet op beginscherm* → open via het icoon → tab Meldingen → *Meldingen aanzetten*
- **Android:** open in Chrome → tab Meldingen → *Meldingen aanzetten* (optioneel: *Toevoegen aan startscherm*)

Iedereen kiest eerst zijn eigen naam; meldingen gaan naar de naam die op dat toestel gekozen is.

## Let op
Geen echte login: wie de link heeft kan als iedereen aanvragen of stemmen. Deel de link alleen met het gezin.
Zet nooit de service_role key, VAPID_PRIVATE_KEY of NOTIFY_SECRET in GitHub.
