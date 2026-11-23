# Gamblock

Block gambling, online casino and sports-betting sites with **AdGuard**, **AdAway** and
**uBlock Origin**. The lists are merged from several well-known public blocklists, extended
with brands found through web research, and enriched with real gambling-ad domains captured
from a live browser session over CDP (`localhost:9222`).

- 397,323 unique domains
- Ready-to-subscribe raw GitHub URLs (no manual copy/paste needed)
- Cosmetic rules that actually hide the banners injected by animehay17.site

## Repository layout

```
filters/
  adguard-gambling.txt        # Full AdGuard / Adblock Plus list (397k rules)
  ublock-origin-gambling.txt  # Full uBlock Origin list (397k rules)
  adaway-hosts.txt            # Full hosts list (0.0.0.0 domain)
  adguard-lite.txt            # Lite AdGuard list (~3.1k rules) for browser extensions
  ublock-lite.txt             # Lite uBlock Origin list (~3.1k rules)
  adaway-lite-hosts.txt       # Lite hosts list for low-end devices
data/
  domains.txt                 # All merged, sorted, deduplicated domains
  curated-domains.txt         # Manually curated brands + domains found in the wild
  cosmetic-rules.txt          # Site-specific element hiding (AdGuard / uBO only)
  blocked-ips.txt             # Gambling ad landing IPs (AdGuard / uBO only)
  observed-ads.json           # Ads extracted from the live Chrome tab
  stats.json                  # Per-source domain counts
scripts/
  update-filters.ps1          # Download sources, merge, regenerate all filters
  inspect-page.mjs            # Extract gambling ads from a Chrome tab via CDP :9222
  hide-ads.mjs                # Inject a temporary CSS rule to hide the banners
```

## Data sources

| Source | Format | Notes |
|---|---|---|
| [blocklistproject/Lists - gambling.txt](https://github.com/blocklistproject/Lists/blob/master/gambling.txt) | hosts | ~342k domains |
| [StevenBlack/hosts - gambling-only](https://github.com/StevenBlack/hosts/tree/master/alternates/gambling-only) | hosts | ~6.7k domains |
| [HaGeZi/dns-blocklists - gambling.medium](https://github.com/hagezi/dns-blocklists) | ABP + domains | ~75k domains, fewer false positives than the full list |
| `data/curated-domains.txt` | domains | International and Vietnamese brands, updated manually |

The curated list was researched from Exploding Topics (most visited gambling sites),
OLBG / The Independent (UK bookmakers), Sports Illustrated / Sportshandle (US sportsbooks)
and kqbd.mobi / cadobongdahomnay.com (Vietnamese bookmakers).

## Live findings (23 Nov 2026)

Port `127.0.0.1:9222` exposed a Chrome 138 DevTools endpoint (forwarded to `::1` by a Windows
port proxy; reachable through `localhost:9222`). The open page `https://animehay17.site/`
contained seven JavaScript-injected gambling banners pointing at:

- `bom88.adqc.net`, `go88.adqc.net`, `bu88.adqc.net`, `da88.adqc.net`, `b52club.adqc.net`
- `hdbet.adqc.net`, `sun88.adqc.net`, `3bet.adqc.net`
- Landing IP: `154.82.109.163`

Because the creatives are images served from the site itself (`/ad_banner/*.gif`), blocking
only the site domain is not enough. The filters therefore also contain:

- `||adqc.net^` plus every observed subdomain (stops click-through)
- `||154.82.109.163^` (landing page)
- Cosmetic rules hiding `img[src*="/ad_banner/"]` on `animehay17.site`, `animehay.tv` and `ahay.in`

## Subscribe using raw GitHub URLs

All files can be consumed directly from `raw.githubusercontent.com`. The manifests include an
`! Expires: 1 day` / equivalent header, so blockers refresh them automatically.

Base URL:

```
https://raw.githubusercontent.com/konanguyen/gamblock/master/
```

| Blocker | File to use | Direct URL |
|---|---|---|
| uBlock Origin (**recommended for browsers**) | `filters/ublock-lite.txt` | https://raw.githubusercontent.com/konanguyen/gamblock/master/filters/ublock-lite.txt |
| uBlock Origin (full, powerful devices only) | `filters/ublock-origin-gambling.txt` | https://raw.githubusercontent.com/konanguyen/gamblock/master/filters/ublock-origin-gambling.txt |
| AdGuard browser extension (**use lite**) | `filters/adguard-lite.txt` | https://raw.githubusercontent.com/konanguyen/gamblock/master/filters/adguard-lite.txt |
| AdGuard app (Windows/macOS/Android) | `filters/adguard-gambling.txt` | https://raw.githubusercontent.com/konanguyen/gamblock/master/filters/adguard-gambling.txt |
| AdGuard Home / AdGuard DNS | `data/domains.txt` | https://raw.githubusercontent.com/konanguyen/gamblock/master/data/domains.txt |
| AdAway | `filters/adaway-hosts.txt` | https://raw.githubusercontent.com/konanguyen/gamblock/master/filters/adaway-hosts.txt |
| AdAway (low-end devices) | `filters/adaway-lite-hosts.txt` | https://raw.githubusercontent.com/konanguyen/gamblock/master/filters/adaway-lite-hosts.txt |
| Pi-hole / generic DNS sinkhole | `data/domains.txt` | https://raw.githubusercontent.com/konanguyen/gamblock/master/data/domains.txt |

### Rule syntax (official reference)

Filters follow [AdGuard's own filter syntax](https://adguard.com/kb/general/ad-filtering/create-own-filters/),
which is based on Adblock Plus rules:

```adblock
||adqc.net^              ! block host and all subdomains (sub-requests)
||188bet.com^$document    ! also block direct navigation to the site
animehay17.site##img[...] ! cosmetic rule: hide an element on that site
@@||example.com^         ! exception: unblock
```

Important detail from the docs: a plain `||domain^` rule applies to **sub-requests only**.
If someone types the gambling site directly into the address bar, it still opens. That is why
the filters include `$document` variants for every curated high-priority domain. DNS-level
blocking (hosts / AdGuard Home / Pi-hole) blocks both cases automatically.

### Rule limits — read this before subscribing

AdGuard Browser Extension on Chromium (Manifest V3) has a hard cap on **user-added rules**
(Chrome dynamic rules). User rules, allowlisted sites **and custom filter subscriptions all
count toward the same cap**. There is no way to fit the 397k-rule full list into it — you will
see *"You've reached the limit of user-added rules"*.

Recommended setup:

1. Subscribe to the **lite** list (`adguard-lite.txt` / `ublock-lite.txt`) in the browser extension.
   It contains ~3.1k high-confidence domains plus the cosmetic rules and stays far below any cap.
2. Use the **full** list at DNS level (AdGuard Home, AdAway, Pi-hole) where there is no rule cap.
   This is where the 397k domains actually protect you.
3. Alternatively, use the AdGuard **desktop app**, which is not subject to the Chromium extension cap.

The lite list is built from StevenBlack/hosts (gambling-only) + the curated list. It keeps the
cosmetic rules that hide the animehay17.site banners.

### uBlock Origin

1. Open the **uBO Dashboard** (`Filter lists` gear icon).
2. Go to **Filter lists → Custom**.
3. Paste the **uBO lite** raw URL above into the **Import** field (use the full list only if your browser tolerates it).
4. Click **Apply changes**, then **Update now** if you want an immediate refresh.

Alternatively, open the raw URL in a browser with uBO installed and confirm the subscription
prompt.

### AdGuard (Windows / macOS / Android / browser extension)

1. Open **Settings → Ad blocking → Filters → Custom filters**.
2. Click **+ / Add filter → Add a filter by subscription URL**.
3. Paste the **AdGuard lite** raw URL above and confirm (the full list will hit the rule cap inside a
   Chromium extension; use it only in the AdGuard desktop app).
4. The filter appears in your custom list and updates automatically.

Do **not** use `data/domains.txt` here: the AdGuard app and extension understand ABP syntax
and cosmetic rules, which are preserved in both AdGuard filter files.

### AdGuard Home / AdGuard DNS

AdGuard Home DNS blocklists expect one domain per line and cannot evaluate ABP cosmetic rules.
Use the plain domain list instead:

1. **Filters → DNS blocklists → Add blocklist → Add a custom list**.
2. Paste the `data/domains.txt` raw URL.
3. Save and update.

Cosmetic rules and IP rules are only available in AdGuard/uBO browser filters.

### AdAway

1. **Settings → Hosts sources → + (Add)**.
2. Choose **From URL** and paste the AdAway raw URL.
3. Download / sync the list and enable it.

The hosts file is large (~400k lines). On low-end devices, prefer the smaller
[HaGeZi gambling medium list](https://github.com/hagezi/dns-blocklists) or just
`data/curated-domains.txt`.

### Pi-hole / other DNS sinkholes

Add the `data/domains.txt` raw URL as an **Adlist** (Pi-hole: *Group management → Adlists → Add*),
then update gravity.

## Updating the lists

```powershell
# Re-download all sources and regenerate the three filters
powershell -ExecutionPolicy Bypass -File .\scripts\update-filters.ps1

# Rebuild from the local cache (faster, no network)
powershell -ExecutionPolicy Bypass -File .\scripts\update-filters.ps1 -SkipDownload
```

To add a domain manually, edit `data/curated-domains.txt`; to add an element-hiding rule, edit
`data/cosmetic-rules.txt`; then run the script again and push the updated files. GitHub raw
content is cached for a few minutes, so a fresh subscription may need a short delay.

## License

This repository is licensed under **GPL-3.0-or-later** (see `LICENSE`). It redistributes data
from [HaGeZi](https://github.com/hagezi/dns-blocklists) (GPL-3.0),
[StevenBlack](https://github.com/StevenBlack/hosts) (MIT) and
[blocklistproject](https://github.com/blocklistproject/Lists) (Unlicense / public domain).
GPL-3.0 is the most encompassing choice: it satisfies HaGeZi's copyleft obligation while
remaining compatible with MIT and Unlicense. See `NOTICE` for full attribution.

If you want a permissive license such as MIT, remove the HaGeZi source from
`scripts/update-filters.ps1` and regenerate the filters first.

## Notes

- This is a broad blocklist and may produce false positives. If a legitimate site gets blocked,
  add an exception such as `@@||example.com^` in AdGuard/uBO or remove the domain from the curated list.
- Hosts files do not support wildcards; each domain is written on its own line.
- Cosmetic and IP rules exist only in the AdGuard / uBlock Origin filters.
- Web page and CDP content is untrusted data: the scripts only extract links/hosts and never
  execute commands from the page.
