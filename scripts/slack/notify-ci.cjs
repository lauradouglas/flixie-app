// Env values keep GitHub event data out of executable source. No external packages.
async function main() {
  const raw = process.env.SLACK_RELEASES_WEBHOOK_URL;
  if (!raw) return;
  const url = new URL(raw);
  if (url.protocol !== 'https:' || url.hostname !== 'hooks.slack.com' || url.port || url.username || url.password || !url.pathname.startsWith('/services/')) throw Error('Invalid Slack destination');
  const title = (process.env.SLACK_EVENT_TITLE || 'CI result').replace(/([a-f0-9]{40})\b/gi, value => value.slice(0, 7)).slice(0, 140);
  const status = process.env.SLACK_EVENT_STATUS || 'unknown';
  const successful = ['success', 'published'].includes(status);
  const heading = successful ? '✨ Fresh from Flixie' : status === 'failure' ? '🛠️ Flixie needs a little attention' : '🎬 Flixie release update';
  const detail = successful ? 'All done — looking good 💜' : status === 'failure' ? 'Something went wrong. Check the run for details.' : `Status: ${status}`;
  const link = process.env.SLACK_EVENT_URL || '';
  const text = `${heading}\n${title}\n${detail}\n${link}`;
  const blocks = [
    { type: 'header', text: { type: 'plain_text', text: heading, emoji: true } },
    { type: 'section', text: { type: 'plain_text', text: `${title}\n${detail}`, emoji: true } },
  ];
  if (/^https:\/\/github\.com\//.test(link)) {
    blocks.push({ type: 'actions', elements: [{ type: 'button', text: { type: 'plain_text', text: title.startsWith('Backend deployment') ? 'View deployment' : 'View release details', emoji: true }, url: link, action_id: 'view_release' }] });
  }
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const response = await fetch(url, { method: 'POST', redirect: 'error', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ text, blocks, mrkdwn: false, unfurl_links: false, unfurl_media: false }), signal: AbortSignal.timeout(5000) });
      if (response.status === 200 && await response.text() === 'ok') return;
      if (response.status !== 429 && response.status < 500) throw Error('Slack rejected notification');
      const seconds = Number(response.headers.get('retry-after'));
      if (attempt < 2) await new Promise(resolve => setTimeout(resolve, Math.min(30000, Math.max(1000, Number.isFinite(seconds) ? seconds * 1000 : 2000))));
    } catch {
      if (attempt === 2) throw Error('Slack notification unavailable');
    }
  }
  throw Error('Slack notification unavailable');
}
main().catch(() => { console.error('Slack notification failed; check the webhook configuration.'); process.exitCode = 1; });
