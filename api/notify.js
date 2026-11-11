// Vercel-functie: wordt door Supabase aangeroepen bij een aanvraag, stem of intrekking
// en stuurt pushmeldingen naar de juiste personen.
const webpush = require("web-push");

const PEOPLE = ["Boris", "Job", "Mama"];
const others = who => PEOPLE.filter(p => p !== who);
const SB_URL = process.env.SUPABASE_URL;
const SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

async function sb(path, opts = {}) {
  const res = await fetch(`${SB_URL}/rest/v1/${path}`, {
    ...opts,
    headers: { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}`, "Content-Type": "application/json", ...(opts.headers || {}) }
  });
  if (!res.ok) throw new Error(`Supabase ${res.status}: ${await res.text()}`);
  return res.status === 204 ? null : res.json();
}

const DAYS = ["zo", "ma", "di", "wo", "do", "vr", "za"];
const MONTHS = ["jan", "feb", "mrt", "apr", "mei", "jun", "jul", "aug", "sep", "okt", "nov", "dec"];
function summary(items = []) {
  const byDay = {};
  for (const it of items) (byDay[it.d] = byDay[it.d] || []).push(it.s);
  const order = ["ochtend", "middag", "avond"];
  const parts = Object.keys(byDay).sort().map(d => {
    const [y, m, dd] = d.split("-").map(Number);
    const wd = DAYS[new Date(Date.UTC(y, m - 1, dd)).getUTCDay()];
    const slots = byDay[d].sort((a, b) => order.indexOf(a) - order.indexOf(b)).join(", ");
    return `${wd} ${dd} ${MONTHS[m - 1]} ${slots}`;
  });
  return parts.length > 3 ? `${parts.slice(0, 3).join(" · ")} +${parts.length - 3}` : parts.join(" · ");
}

async function sendTo(names, payload) {
  if (!names.length) return 0;
  const subs = await sb(`push_subscriptions?name=in.(${names.map(encodeURIComponent).join(",")})&select=endpoint,subscription`);
  let sent = 0;
  await Promise.all(subs.map(async s => {
    try { await webpush.sendNotification(s.subscription, JSON.stringify(payload)); sent++; }
    catch (e) {
      if (e.statusCode === 404 || e.statusCode === 410) {
        await sb(`push_subscriptions?endpoint=eq.${encodeURIComponent(s.endpoint)}`, { method: "DELETE" }).catch(() => {});
      } else console.error("push error", e.statusCode, e.body);
    }
  }));
  return sent;
}

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).end();
  if (!process.env.NOTIFY_SECRET || req.headers["x-notify-secret"] !== process.env.NOTIFY_SECRET) return res.status(401).end();
  try {
    webpush.setVapidDetails(process.env.VAPID_SUBJECT || "mailto:info@flyingimages.nl", process.env.VAPID_PUBLIC_KEY, process.env.VAPID_PRIVATE_KEY);
    const body = typeof req.body === "string" ? JSON.parse(req.body) : (req.body || {});
    const { kind, request_id, voter, vote } = body;
    const [request] = await sb(`requests?id=eq.${encodeURIComponent(request_id)}&select=*`);
    if (!request) return res.status(200).json({ skipped: "no request" });
    const by = request.by_name;
    const what = summary(request.items);
    const tag = `req-${request.id}`;
    let sent = 0;

    if (kind === "request") {
      sent += await sendTo(others(by), { title: `🚗 ${by} vraagt de auto`, body: `${what}${request.note ? ` — ${request.note}` : ""}`, tag });
    } else if (kind === "cancel") {
      sent += await sendTo(others(by), { title: `↩️ ${by} heeft een aanvraag ingetrokken`, body: what, tag });
    } else if (kind === "vote") {
      const votes = await sb(`votes?request_id=eq.${encodeURIComponent(request_id)}&select=voter,vote`);
      const v = Object.fromEntries(votes.map(x => [x.voter, x.vote]));
      const approvers = others(by);
      const third = approvers.find(p => p !== voter);
      if (vote === "no") {
        sent += await sendTo([by], { title: `❌ ${voter} heeft je aanvraag afgewezen`, body: what, tag });
      } else if (approvers.every(p => v[p] === "yes")) {
        sent += await sendTo([by], { title: "✅ Je aanvraag is goedgekeurd", body: `De auto is van jou: ${what}`, tag });
        sent += await sendTo(approvers.filter(p => p !== voter), { title: `✅ ${by} heeft de auto`, body: what, tag });
      } else {
        sent += await sendTo([by], { title: `👍 ${voter} is akkoord`, body: `Wacht nog op ${third} · ${what}`, tag });
      }
    }
    return res.status(200).json({ ok: true, sent });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: String(e.message || e) });
  }
};
