# Vanya: Guardians of the Grove — Cross-Platform, Re-skinnable, AI-Adaptive Development Plan (Android + iOS)

**Stay on Godot 4.7.x, and build Vanya as one app whose gameplay is data-driven. Themes should be downloadable packs that contain assets only. An on-device procedural generator and a statistical difficulty controller should do all the moment-to-moment adaptation. Use LLMs and image models offline, or at most once or twice per player per day, and never inside the frame loop.** In 2026 the Godot iOS plugin gaps that used to push small studios to Unity are mostly closed. Poing AdMob v5.1 has UMP, SPM and 17 mediation networks.\[1\] OpenIAP godot-iap covers StoreKit 2 plus Play Billing 8.\[2\]\[3\] There is a Firebase iOS GDExtension. Runtime AI does not change the engine choice, because the AI runs on your server.

## TL;DR
- **Engine and stack:** Godot 4.7.2 using the Compatibility renderer, plus these plugins:
  - Poing AdMob v5.1 (UMP, ATT via the IDFA explainer, AdMob bidding mediation)
  - godot-iap (StoreKit 2 and Play Billing 8+), or GodotGooglePlayBilling 3.x on Android
  - Firebase (Analytics and Remote Config) through platform plugins
  - Your M4 Pro Mac with Xcode for iOS builds

  Pick Unity 6 only if you later need AppLovin MAX/LevelPlay as the primary SDK or Addressables-scale live ops. Today's official AppLovin MAX Godot plugin (1.2.0) hasn't been updated since April 2025.\[4\]
- **Theme feasibility:** ship **one** app. Presentation lives in "theme packs": Godot resource packs (PCK) that hold **no scripts**. Assign themes through Remote Config and campaign-specific store listings (Play custom store listings, iOS custom product pages). Judge each theme on CPI, then D1/D7. **Do not** publish one reskinned app per theme. Apple 4.3(a) now explicitly says "Don't create multiple Bundle IDs of the same app", and Google's repetitive-content policy bans "multiple apps with highly similar functionality".\[5\]
- **Adaptive AI:**
  - Level layout, pathing, spawns and waves are handled by deterministic PCG on the device.
  - DDA v1 is an Elo-style skill rating that aims for a ~75% clear chance, plus a Left 4 Dead-style intensity director inside each room.
  - The LLM "director" only picks from enumerated options and writes flavor text. Its output is validated against a schema, prefetched, cached, and always has an offline fallback.
  - Generative art is an *offline* pipeline with human QA. At runtime, variety comes from composition (palette LUTs, part swaps, shaders), never from live image generation.
  - Expected LLM cost is about $200/month at 10k DAU with a pre-generated plan pool, versus about $670 for a naive "LLM per arc" design.

---

## 1. Executive decisions at a glance

| Decision | Recommendation | Why | Revisit if… |
|---|---|---|---|
| Engine | **Godot 4.7.2** (stable 18 Aug 2026), GDScript, Compatibility renderer\[6\] | You already have prototypes. iOS plugin coverage is now adequate. PCK packs are native. No fees. | You need MAX/LevelPlay as primary mediation, or console ports |
| Ads SDK | **Poing AdMob plugin v5.1.0** (13 Sep 2026) + AdMob bidding mediation (AppLovin, Unity Ads, Mintegral, Pangle, ironSource adapters) | UMP + privacy-options form, SPM on iOS, `on_ad_paid` ILRD, 17+ mediation networks\[1\] | Ad revenue > ~$3–5k/month → A/B test MAX |
| IAP | **godot-iap (OpenIAP)**: StoreKit 2 + Play Billing 8+ in one API.\[2\] Fallback: GodotGooglePlayBilling 3.x (Billing 8; master bumped to 9.1.0 on 26 Jul 2026) + godot-storekit2\[7\]\[8\] | One code path, and meets the Billing 8 gate | Plugin abandonment → wrap native yourself |
| Analytics/config | Firebase Analytics + Remote Config (GodotFirebaseAndroid + SomniGameStudios godot-firebase-ios), **plus** your own FastAPI telemetry for DDA | Firebase handles store/ads linking. Your backend owns the gameplay data. | — |
| Themes | One binary, themes = asset-only PCK packs + JSON manifest | Allowed by both stores; avoids 4.3/repetitive-content risk | — |
| AI | PCG + statistical DDA on device. LLM as an optional planner/narrator. Offline gen-art pipeline. | Latency, cost, offline play, store policy | Costs drop ~10× more *and* the quality bar is proven |
| Account | Google Play **organization** account (CurioSapien Automation Pvt Ltd, D-U-N-S) + Apple Developer Program as organization ($99/yr) | Org accounts are exempt from Play's 12-tester/14-day rule\[9\]\[10\] | — |

---

## 2. Engine re-evaluation (Android + iOS)

### 2.1 Comparison

| Criterion | **Godot 4.7** | Unity 6 | Defold | Cocos Creator | Flutter + Flame |
|---|---|---|---|---|---|
| Language fit (you: Python/TS) | GDScript ≈ Python ✅ | C# (learnable) | Lua | **TypeScript** ✅ | Dart |
| 2D vector cut-out rigs + 2D lights/darkness | Skeleton2D, Polygon2D, PointLight2D, CanvasModulate ✅ | 2D Animation + URP 2D lights ✅ | Spine ext; lighting DIY | Spine; lighting DIY | Weak for dynamic lighting ❌ |
| AdMob iOS+Android | Poing v5.1 (UMP, mediation, SPM) ✅ | Official Google plugin ✅✅ | Official ext ✅ | Community | google_mobile_ads ✅ |
| MAX / LevelPlay | MAX Godot plugin stale (1.2.0, Apr 2025); **no LevelPlay** ⚠️\[4\] | Official, first-class ✅✅ | Community | Partial | Official MAX ✅ |
| IAP (StoreKit 2 + PBL 8) | godot-iap / godot-storekit2 / GPB 3.x ✅ | Unity IAP ✅✅ | Official ext ✅ | ✅ | in_app_purchase ✅ |
| Firebase | Community (iOS GDExtension needs iOS 17+ target) ⚠️ | Official SDK ✅✅ | Community | Community | Official ✅✅ |
| Runtime content packs | **PCK/ZIP `load_resource_pack`** ✅ | Addressables ✅✅ | Live Update ✅ | Asset Bundles ✅ | Manual |
| Licence cost | Free, MIT | Personal free under $200k revenue/funding; splash optional in Unity 6; no runtime fee\[11\]\[12\] | Free | Free | Free |
| Your switching cost | 0 (prototypes exist) | 6–10 weeks at 12–15 h/wk | 4–6 wks | 4–6 wks | 4–6 wks + lighting |

**Verdict:** Godot wins for *this* founder and *this* game. Unity is the strongest second choice, and its advantages are in ad-tech maturity and Addressables. For a solo developer at 12–15 h/week, those gains don't justify rewriting working prototypes. Runtime-downloaded content and AI generation don't favour Unity either. PCK packs cover asset delivery, and AI runs server-side on any engine.

### 2.2 Godot plugin matrix (verify versions at integration time)

| Need | Android | iOS | Notes |
|---|---|---|---|
| Ads | Poing AdMob v5.1.0 | same | Godot 4.4+ (tested through 4.7.2), iOS min 15.0, GMA iOS SDK 13.9.0. v4→v5 is a breaking migration (remove legacy `.gdip`).\[1\] |
| Consent | UMP via Poing | UMP + IDFA explainer → ATT | Poing's docs: publish an IDFA explainer message in AdMob, add `NSUserTrackingUsageDescription`, link AppTrackingTransparency.\[13\] Poing also ships a separate godot-att-ios plugin (Godot 4.6+), and the cengiz-pz/godot-admob plugin has built-in ATT signals.\[14\]\[15\]\[16\] |
| IAP | godot-iap (PBL 8+) or GodotGooglePlayBilling 3.x | godot-iap (StoreKit 2) or godot-storekit2\[3\]\[17\] | Always validate purchases server-side |
| Analytics/RC | GodotFirebaseAndroid | godot-firebase-ios (GDExtension/SwiftGodot, Godot 4.6.1+, Xcode 15+, **iOS 17+**)\[18\] | godot-x/firebase is an alternative modular build |
| Privacy manifest | n/a | Built into Godot's iOS exporter since **4.3**\[19\] | Export options cover the required-reason categories: `privacy/user_defaults_access_reasons`, `file_timestamp`, `system_boot_time`, `disk_space`, `active_keyboard` plus tracking and collected-data declarations.\[20\]\[21\] Ad SDKs bring their own manifests via SPM. |

### 2.3 iOS build pipeline on your MacBook M4 Pro

The pipeline runs like this:
1. Export an iOS preset from the Godot 4.7.2 macOS editor (bundle ID, team ID, `privacy/*` options, iOS 17 minimum target).\[22\]
2. Open the generated Xcode project. SPM resolves the GMA SDK and the mediation adapters.\[1\]
3. Archive and upload to App Store Connect, then distribute through TestFlight (internal testing is instant; external testing needs beta review).
4. Submit for App Review and release with phased release switched on.

- Enroll in the Apple Developer Program as an organization ($99/yr). Enrollment needs the D-U-N-S number you already have.
- Check Apple's "Upcoming Requirements" page for the minimum Xcode/SDK version App Store Connect accepts before your first upload.

### 2.4 Store compliance checklists

**Google Play (2026)**
- [ ] `targetSdkVersion 36`. It has been required for new apps and updates since **31 Aug 2026**, and the extension ran to 1 Nov 2026.\[23\]\[24\]
- [ ] 16 KB page-size support (required once you target API 35+). Test every `.so` from plugins.\[25\]
- [ ] Play Billing Library **8+**. It is required for new apps and updates since 31 Aug 2026, and PBL 8's own deadline is 31 Aug 2027, so plan to move to PBL 9.x in 2027.\[26\]
- [ ] Organization account, which means no 12-tester/14-day closed test. A personal account created after 13 Nov 2023 would need **12 testers opted in for 14 continuous days**.\[10\]\[27\]
- [ ] Data safety form: device IDs, app activity, diagnostics, purchases. Say whether data is shared with ad networks.
- [ ] Target audience 13+ (or 16+) so you stay out of Families policy (see §5.7).
- [ ] AI-generated content: add an **in-app report/flag** button for any AI-generated text or images (see §6.5).\[28\]

**Apple App Store**
- [ ] Privacy nutrition labels match the SDKs you ship (Identifiers, Usage Data, Diagnostics, Purchases; "Tracking" = yes if ATT is used).
- [ ] PrivacyInfo.xcprivacy: set Godot's export `privacy/*` reasons, and confirm the ad SDK manifests are included.\[20\]\[29\]
- [ ] ATT prompt appears only after an explainer and after the first grove, not at launch. Gameplay must never depend on consent (5.1.2(i)).\[30\]
- [ ] Disclose sharing player data with **third-party AI** and get explicit permission (5.1.2(i) now names "third-party AI" explicitly).\[30\]
- [ ] Ads: interstitials must be clearly marked, with visible close buttons, and users must be able to **report inappropriate ads** (2.5.18).\[30\]
- [ ] The default theme is bundled. Any required download must show its size and ask first (4.2.3(ii)).\[30\]
- [ ] Review notes describe the theme system, remote packs and the AI director (2.3.1(a) bans "hidden, dormant, or undocumented features").\[30\]

---

## 3. Theme-pack architecture (re-skinnable by design)

### 3.1 Principle: gameplay is written against *archetypes*, never against art

The code ships in the binary and knows only about archetypes. Examples are SWARM, TANK, RANGED, BOSS, CAGE_TARGET, CURRENCY_A/B, BUFF_GOD_1..3, META_GOD_1..4, GUIDE_1..2, OBSTACLE, LIGHT_SOURCE, EXIT_GATE and PORTAL. `ThemeRegistry.resolve(archetype_id)` returns the presentation bundle from the active theme pack. A pack holds data and assets only, never scripts:
- `manifest.json`
- rigs (`.tscn` with sprites and Skeleton2D)
- tileset and palette
- VFX
- SFX and music
- UI theme and fonts
- localized strings
- lighting

| Layer | Owned by gameplay | Owned by theme |
|---|---|---|
| Entity stats (HP, speed, damage, costs) | ✅ `data/entities/*.tres` | ❌ (keep identical across themes so tests are clean) |
| Entity visuals, hitbox *shape* | Hitbox radius stays in gameplay | Rig, animations, death VFX, SFX |
| Currencies | Rules, drop rates | Icon, name ("meat"/"scrap"/"pearls"), colour |
| Gods/guides | Effect, cost, cooldown | Name, portrait, VFX, voice line, lore |
| Rooms | Grid 22×30, PCG rules, tile *semantics* (wall/floor/hazard) | Tileset art, props, decoration density |
| Lighting | Darkness level as a gameplay value | Ambient colour, light textures, fog tint |
| UI | Layout scenes, flow | `Theme` resource, 9-patches, fonts, SFX |
| Text | String *keys* | Localized strings per theme and locale |

For example, SWARM maps to Rotling in the tribal forest, nanite mites in space, a piranha shoal underwater, and crawlers in the zombie theme. CURRENCY_A/B maps to meat/spirit, scrap/plasma, pearls/bubbles, or supplies/serum.

### 3.2 Theme manifest (JSON, versioned)

```json
{
  "theme_id": "tribal_forest", "version": "1.3.0", "min_game_version": "0.9.0",
  "pack": {"file": "tribal_forest_1.3.0.pck", "sha256": "…", "bytes": 18432000},
  "fonts": {"display": "…/Baloo2.ttf", "body": "…/Hind.ttf"},
  "archetypes": {"SWARM": {"rig": "res://themes/tribal_forest/rigs/rotling.tscn", "name_key": "ENEMY_SWARM_NAME"}},
  "tileset": "…/tiles.tres", "ui_theme": "…/ui_theme.tres", "strings": ["…/en.csv", "…/hi.csv", "…/mr.csv"]
}
```
Path convention: every pack mounts under `res://themes/<theme_id>/…`, so packs can never overwrite each other or the core.

### 3.3 Runtime loading flow

```mermaid
sequenceDiagram
  participant Boot as Autoload ThemeLoader (_init)
  participant RC as Remote Config / your API
  participant CDN as Azure Blob + Front Door
  participant FS as user://themes/
  Boot->>FS: default theme is in binary (res://themes/tribal_forest)
  Boot->>RC: fetch assigned_theme, manifest_url (cached, 12h)
  alt assigned theme not cached
    Boot->>CDN: GET manifest.json → verify signature
    Boot->>CDN: GET pack.pck (Wi-Fi or user OK; size shown)
    Boot->>FS: store, verify sha256
  end
  Boot->>Boot: validate pack contains no .gd/.gdc/.cs/.gdextension
  Boot->>Boot: ProjectSettings.load_resource_pack(path, false)
  Boot->>Boot: ThemeRegistry.activate(theme_id) → swap UI Theme, strings, tileset
```
Implementation notes:
- Godot's docs recommend loading packs as early as possible, in an autoload's `_init()`.\[31\]
- Pass `replace_files=false` so a theme can never shadow core files.\[31\]\[32\]
- Already-loaded resources are cached, so switch themes at a scene boundary (camp screen), not mid-room.\[32\]
- Export packs with an **include filter of asset extensions only**, and add a CI check that fails the build if a pack contains any script.

### 3.4 Store policy on downloaded content

| Rule | Text (paraphrased or quoted) | What it means for Vanya |
|---|---|---|
| Apple 2.5.2 | Apps may not "download, install, or execute code which introduces or changes features or functionality of the app"\[30\] | Theme packs must be **assets/data only**. A PCK can carry GDScript, and shipping gameplay logic that way is the risk. Keep all logic in the binary. |
| Apple 4.2.3(ii) | Disclose download size and prompt before downloading resources needed on first launch\[30\] | Bundle the default theme; other themes are optional downloads |
| Apple 2.3.1(a) | No hidden or undocumented features; describe changes in review notes\[30\] | Document the remote theme and AI director in review notes |
| Google Play Device & Network Abuse | Apps may not download executable code (dex/JAR/.so) outside Play; interpreted code is treated differently | Same answer: no code in packs. Use Play Asset Delivery if packs get large. |
| Apple 4.3(a) | "Don't create multiple Bundle IDs of the same app… consider submitting a single app and providing the variations using in-app purchase"\[5\]\[30\] | Themes live inside one app (free or IAP "Worlds") |
| Apple 4.3(b) (updated 8 Jun 2026)\[33\] | "Don't submit apps that are indistinguishable from what's already widely available"\[33\] | A flood of reskins is exactly what this targets |
| Google Play Spam: repetitive content | "Creating multiple apps with highly similar functionality, content and user experience" is a violation\[34\] | Same |

### 3.5 Theme A/B testing and feasibility measurement

The test runs in four stages:

| Stage | What you do | Metrics |
|---|---|---|
| 0 (no build needed) | Key art + 15 s gameplay mock per theme | CTR, IPM |
| 1 (creative test) | Google App campaigns / Meta, India, $150–300 per theme | CPI, install CVR |
| 2 (in-app test) | Remote Config random assignment + CPP/CSL per theme | D1, D7, session length, ARPDAU, rewarded views/DAU |
| 3 (decision) | Winner becomes the default theme + store listing swap, in the same app | — |

**Mechanics:**
- **Google Play:** create one custom store listing per theme (up to 50).\[35\] Link each campaign to its listing. Read the Play Install Referrer's `utm_content=theme_x` on first launch, set the starting theme to match, and log `theme_source=referrer`.
- **iOS:** create one custom product page per theme (up to 70, each with its own keywords and deep link).\[36\] No install-time parameter is guaranteed, so first launch shows a 2-card "choose your world" picker, with the CPP's theme first when a deep link is available. For organic users, Remote Config assigns a theme at random.
- **Store A/B:** Play store listing experiments and Apple Product Page Optimization (up to 3 treatments vs original, visual assets only) test icons and screenshots per theme.\[36\]\[37\]
- **Attribution hygiene:** log `theme_id` as a Firebase **user property** and on every telemetry event. Assign exactly once and persist it.

**Sample size per theme arm** (two-proportion test, α=0.05, power 0.8):

| Metric difference to detect | Installs per theme |
|---|---|
| D1 35% vs 30% | ~1,400 |
| D7 12% vs 9% | ~1,650 |
| CPI ±20% (creative stage) | ~300–500 installs is enough to rank themes |

**Decision rule:** a theme "wins" if its CPI is ≤ 0.8× the control's *and* its D1/D7 are not significantly worse. Retention beats CPI. A cheap install that churns is worth nothing.

### 3.6 If a theme wins: one codebase, several apps?

| Option | Policy risk | Recommendation |
|---|---|---|
| Swap the flagship's default theme and listing | None | ✅ First move |
| Sell other themes as IAP "Worlds" in the same app | None (Apple suggests exactly this)\[30\] | ✅ |
| Separate app, same game, different skin | **High** (Apple 4.3(a)/(b), Play repetitive content; repeated cases can cost the developer account)\[30\]\[34\] | ❌ |
| Separate app on the same engine, with a **materially different loop** (new meta, modes, progression, controls) | Low–medium | ✅ only when justified; build it as a "product flavor" of the shared core |

Structure the repo so the core is a Godot addon (`addons/vanya_core/`) and each product is a thin project with its own design data. That way a second *game* reuses 60–80% of the code without reusing its identity.

---

## 4. Monetization overview

| Stream | Placement | Rules |
|---|---|---|
| Rewarded: Revive | Death screen, once per grove | Opt-in, never auto-play; Kaja/meta-god can grant a free revive for payers |
| Rewarded: Double rewards | Grove-clear chest | 1× per grove; cap ~8/day |
| Rewarded: Free spirit | Camp shrine | 3/day, cooldown 30 min |
| Interstitial | Only on **camp return** after ≥3 rooms | See pacing below |
| Banner (optional) | Camp screen only, never in combat | Low eCPM; test whether it's worth the clutter |
| App open | **Not in v1** | Hurts first impression in an action game; test later only for returns after >4 h |
| IAP | Remove Ads (non-consumable, ₹199–299), Starter Pack, Spirit packs, Worlds (themes) | Remove Ads removes interstitials and banner; keep rewarded as opt-in with the reward granted |

---

## 5. AdMob integration in detail (both platforms)

### 5.1 Interstitial pacing rules (implement as a Remote Config–tunable `AdPacer`)

- [ ] None in the first session, and none before the player has cleared 3 groves.
- [ ] Only at natural breaks: camp return or a chapter end. Never on death (the revive screen is already an ad moment) and never mid-room.
- [ ] Global cooldown ≥ 180 s. Also ≥ 90 s after any rewarded view.
- [ ] Session cap 4 and daily cap 12 (start conservative, tune by retention).
- [ ] Zero interstitials for payers or Remove Ads owners.
- [ ] Log `ad_opportunity`, `ad_shown`, `ad_failed` with placement IDs so you can measure fill and retention impact per placement.

### 5.2 Mediation choice

| Option | Pros | Cons for Godot solo dev | Verdict |
|---|---|---|---|
| **AdMob mediation with bidding** (via Poing v5) | One SDK; adapters for AppLovin, Unity Ads, ironSource, Mintegral, Pangle, InMobi, Moloco, etc.; SPM on iOS\[1\] | AdMob itself held only 7% of iOS ad revenue in Q1 2026, tied with Liftoff (Tenjin × CAS benchmark), so you depend on adapters bidding well | ✅ **Launch choice** |
| AppLovin MAX | AppLovin led iOS ad revenue share at 39% in Q1 2026 (Tenjin/CAS)\[38\] | Official Godot plugin last released 24 Apr 2025, manual CocoaPods/Gradle steps, unverified on 4.6/4.7\[4\] | Revisit once you have more revenue |
| Unity LevelPlay (ironSource) | Strong in games | **No official Godot plugin**; community ones are old and Android-only\[39\]\[40\] | ❌ (use ironSource as an AdMob adapter instead) |

### 5.3 eCPM expectations (use for planning only)

| Format | US / Tier-1 | India | Source/notes |
|---|---|---|---|
| Rewarded video | ~$14–22 (RevenueLab 2026), $15–30 (Playwire)\[41\]\[42\] | Tier-3 ~$2–3 (RevenueLab); in practice India Android is often lower\[42\] | Q2 2026: India Android rewarded eCPM fell 5.18% QoQ (Bidlogic)\[43\] |
| Interstitial | ~$5–8 (Playwire Tier-1)\[41\] | ~$0.5–1.5 (planning assumption) | |
| App open | US $7.35–10.51 (2024)\[44\] | India $0.44–0.57 (2024, MonetizeMore)\[44\] | Shows the ~15–20× geo gap |
| Banner | $0.50–1.50 Tier-1\[41\] | cents | |

**What this means:** an India-first game is volume- and retention-driven. At India eCPMs, ~2 rewarded plus ~1 interstitial per DAU gives roughly $0.005–0.02 ARPDAU (assumption). Tier-1 soft-launch markets (Canada) exist to measure LTV ceilings, not to make money.

### 5.4 Consent flow (UMP + ATT)

1. On first launch, call UMP `requestConsentInfoUpdate`. If a form is required (EEA/UK/US states), show it.
2. On iOS, after the player clears grove 1, show the UMP IDFA explainer, then the ATT system prompt.\[13\]
3. Initialize the Mobile Ads SDK only once `canRequestAds` is true, and pass the consent state into Firebase Consent Mode.
4. In Settings, a "Privacy options" button calls `present_privacy_options_form`.\[1\]

- **ATT effect:** games opt in more than other apps. Singular's Q2 2024 data shows 18.58% immediate opt-in for games vs 11.92% for non-gaming apps (13.85% overall). Adjust's Mobile App Trends 2026 reports 38% industry-wide opt-in in Q1 2026, with gaming leading at 39%. On the revenue side, a Deconstructor of Fun roundtable with ad-monetization consultant Felix Braberg (Dec 2023) reported that the eCPM gap between consented and non-consented iOS users shrank from 60% to 18%. Braberg dates that shift to within weeks of iOS 14.5 and puts it down to fingerprinting. So ATT matters, but it doesn't kill revenue. Ask after the first win, not at launch.

### 5.5 Test ads and QA
- [ ] Use Google's sample ad unit IDs, plus register your devices as test devices in code.
- [ ] Use AdMob Ad Inspector (supported by Poing v5) to verify each mediation adapter.\[1\]
- [ ] Never click live ads on your own devices. Invalid traffic can get your AdMob account suspended.
- [ ] Test UMP with a debug geography (EEA) and reset consent between runs.

### 5.6 Ad-revenue analytics (ILRD)
- Connect Poing's `on_ad_paid` callback to Firebase's `ad_impression` event: `value`, `currency`, `precision`, `ad_source`, `ad_unit`, `placement`, plus your `theme_id` and `dda_band`.\[1\]
- Link AdMob to Firebase so Analytics gets AdMob revenue and you can see ARPDAU by theme.
- Mirror the event to your backend for LTV modelling in Postgres.

### 5.7 Families policy avoidance
- Set the target age to 13+ or 16+ in Play Console, and answer the IARC questionnaire honestly (fantasy violence).
- Keep "for kids" language out of your metadata (Apple 2.3.8 reserves it for the Kids Category).\[30\]
- Warli art can read as child-appealing, so keep creatives mature (night, tension, combat) and avoid cartoon-baby characters in marketing.
- **India DPDP Act:** a "child" is anyone under 18, and targeted advertising or behavioural monitoring of children is restricted as the rules phase in. Add an age gate at first launch. Under-18 users get non-personalized ads and minimal telemetry. Take legal advice before scaling.

### 5.8 User acquisition: Google Ads App campaigns + Firebase conversions

| Phase | Campaign goal | Conversion event (from Firebase) | Budget/day (India) |
|---|---|---|---|
| Theme tests | Installs | `first_open` | $15–30 per theme |
| Quality | In-app action | `grove_5_cleared` (fires for ~25–35% of installs) | $20–50 |
| Scale (post-go) | tROAS | `ad_impression` value + `purchase` | $50+ |

- On iOS, Google Ads attribution relies on SKAdNetwork/AdAttributionKit plus consented signals. Expect coarser data and judge iOS on cohort metrics, not user-level ROAS.
- Creatives: 3 per theme (15 s gameplay, 6 s hook, static). Real gameplay only, since metadata and ads must match the app (Apple 2.3).\[30\]

---

## 6. AI-generated levels and assets, adapted per player

### 6.1 Who does what

| Content | Technique | Where | Latency | Cost | Offline |
|---|---|---|---|---|---|
| Room layout (22×30) | Hand-authored **chunk templates** + BSP / WFC-lite fill + Poisson-disk scatter of idols/torches | Device | <10 ms | 0 | ✅ |
| Pathing/solvability | Flood fill + A* on grid; NavigationRegion2D bake | Device | <5 ms | 0 | ✅ |
| Spawn portal & cage placement | Constraint rules (min distance from start, line-of-sight rules, reachability) | Device | <2 ms | 0 | ✅ |
| Wave composition | **Difficulty budget** → point-buy of archetypes | Device (budget from DDA) | <1 ms | 0 | ✅ |
| Next-room difficulty | Statistical DDA (§7) | Device (server re-syncs rating) | 0 | 0 | ✅ |
| Grove "arc" plan (5 rooms: modifiers, template families, pacing, boss variant) | **LLM director**, choosing from enumerations | Server, prefetched | 1–4 s (hidden) | ~$0.001–0.002/call | Fallback |
| Flavor text (grove title, spirit whisper, modifier explanation) | LLM, from a curated style guide, cached | Server | hidden | tiny | Fallback lines |
| Enemy variants, props, palettes, backgrounds | **Offline** gen-AI → human vector redraw → runtime composition | Studio pipeline | n/a | one-off | ✅ |

### 6.2 On-device PCG pipeline

```
seed ─► pick template family (from plan or DDA default)
     ─► place fixed features: start pad, exit gate (opposite edge), 2–4 portals
     ─► fill interior with chunk templates (WFC-lite adjacency rules)
     ─► scatter idols/torches (Poisson disk r≥3 tiles; torches ensure ≥X% lit coverage)
     ─► place cages (reachable, ≥6 tiles from portals, ≤1 behind hazard)
     ─► VALIDATE ─┬─ all of {exit, cages, portals-approach} reachable (flood fill)
                  ├─ open floor ≥ 55%, no dead-end corridors < 3 wide around portals
                  ├─ portal→start path length ≥ 8 tiles (reaction time)
                  └─ fail? reseed (max 5) → fallback to hand-made room #N
     ─► waves = budget_allocator(budget, mix_weights, portals, timeline)
```
The same generator is ported to Python on the server (it's small), so the server can **pre-validate** any LLM plan by running it.

### 6.3 LLM level director v1: constrained JSON planner

**Rule:** the DDA controller sets the *numbers*. The LLM only picks *which* options and writes *words*. That keeps difficulty safe and predictable, and makes the LLM easy to swap or turn off.

**Output schema (`grove_arc_plan.v1`):**
- `arc_id`
- `rooms`: exactly 5 items. Each room has:
  - `template_family`: one of `open_glade`, `idol_maze`, `river_split`, `ring_arena`, `boss_hollow`
  - `modifier_ids`: at most 2, from `fog_thick`, `wisp_surge`, `thorn_rain`, `firefly_bloom`, `none`
  - `mix_bias`: `swarm_heavy`, `tank_heavy`, `ranged_heavy` or `balanced`
  - `cage_count`: an integer from 0 to 3
  - `pacing`: `slow_burn`, `two_peaks` or `relentless_short`
- `narrative`: an `arc_title` of at most 40 characters, plus up to 5 `room_whispers` of at most 90 characters each

**Prompt inputs**, all pseudonymous and aggregated with no PII:
- skill band and trend
- last 10 rooms' outcome summary
- play-style vector (kites vs. face-tanks, god usage, cage priority)
- recent template/modifier history (for novelty)
- theme ID and style guide

**Guardrails pipeline (server):**
```
LLM (structured output / JSON mode) → jsonschema validate → enum/range clamp
  → DDA bounds check (budget untouched; modifiers' difficulty cost ≤ allowance)
  → novelty check (pgvector cosine vs last 20 arcs > threshold)
  → simulate 5 rooms with Python PCG (solvable? pacing curve within bounds?)
  → text moderation (blocklist + small classifier) → cache → return
Any failure → deterministic planner (weighted-random from same enums) — player never waits.
```

**Prefetch timing:**
1. During wave 2 of room 3 in arc N, the client posts a telemetry summary to `/v1/plan/next` and asks for arc N+1.
2. The server checks the pre-generated pool for (theme, skill band, style cluster). Target a hit rate of at least 70%.
3. On a miss, it calls the LLM gateway with a 6 s timeout and one retry on the fallback model, then validates and stores the result.
4. The signed plan is saved locally on the device. If no plan has arrived by the end of the arc, the local deterministic planner takes over.

### 6.4 Runtime generative art: feasibility verdict

| Approach | Latency | Cost | Style consistency | Moderation | Verdict |
|---|---|---|---|---|---|
| Live image gen per player (SDXL/Flux LoRA, Scenario, Layer.ai, Leonardo, OpenAI/Gemini image APIs) | Seconds per image | Per-image fees × DAU. Even $0.02–0.04/image × 1/DAU/day = **$60–120k/month at 100k DAU** (assumption) | Drifts from the vector bible; raster output doesn't fit cut-out rigs | Every image needs a filter plus an in-app report path | ❌ |
| **Offline AI → human QA → vector library → runtime composition** | 0 | One-off | High (a human redraws to the bible) | Pre-screened | ✅ |

**Runtime composition toolkit** (gives cheap "infinite" variety):
1. **Palette LUT shader:** one grayscale-indexed sprite with N palettes per theme (blight tint scales with difficulty band).
2. **Part recombination:** creature rigs as Skeleton2D with swappable head/body/limb/horn slots. For example, 4 heads × 4 bodies × 3 tails = 48 Rotling looks from 11 parts.
3. **Shader variants:** corruption noise, rim glow for elites, dissolve on death, pulsing "spirit" emission.
4. **Procedural decoration:** grass/mushroom/rune decals via a noise mask, respecting gameplay collision.
5. **Named elites:** an LLM-picked prefix (from a list) plus a shader variant plus stat modifiers from DDA, e.g. "Ember-eyed Thornback".

**Offline pipeline:**
```
Brief (bible + archetype) → image model batch (concepts, 20–50/archetype)
  → human pick (5) → vector redraw in Inkscape/Affinity/Illustrator (SVG layers per part)
  → export parts → Godot rig template → QA checklist (silhouette readable at 64 px, palette slots, hitbox match)
  → commit to theme pack
```
Tools worth evaluating: Scenario or Layer.ai (custom style training on your bible), Leonardo, and a vector-native generator such as Recraft for SVG output. PixelLab targets pixel art, which you've rejected. Always check each tool's licence and commercial-use terms.

### 6.5 Store policy on AI content
- **Google Play:** the Developer Program Policy's "AI-Generated Content" section, announced on the Android Developers Blog on 25 Oct 2023, says: "Apps that generate content using AI must contain in-app user reporting or flagging features that allow users to report or flag offensive content to developers without needing to exit the app." Developers must use those reports to improve filtering. Even LLM flavor text qualifies, so add a small ⚑ on AI-generated text cards that opens a report sheet, feeding a `/v1/report` endpoint.
- **Apple:** there is no standalone "AI" guideline. The relevant ones are 1.1 (objectionable content), 5.1.2(i) (disclose and get permission before sharing personal data with **third-party AI**), and 1.2-style moderation duties if content is user-driven.\[30\]\[45\] Keep prompts free of free-text user input so generated content stays within your curated vocabulary.

---

## 7. Dynamic Difficulty Adjustment (DDA)

### 7.1 Research foundations → design choices

| Source | Idea | What we take |
|---|---|---|
| Csikszentmihalyi, flow | Challenge ≈ skill keeps players absorbed | Target a success probability, not a fixed difficulty |
| Hunicke, "The Case for DDA in Games" (ACE 2005), Hamlet on Half-Life | Adjust supply/demand (health, ammo) with inventory-theory predictions; adjustment must not "degrade the core player experience"\[46\]\[47\] | Prefer **supply-side** help (healing drops, spirit, cages) over visible enemy nerfs |
| Booth, "The AI Systems of Left 4 Dead" (GDC 2009) | Track survivor "intensity"; director cycles **Build Up → Sustain/Peak → Relax**; higher difficulty raises threat *frequency*, not amplitude\[48\]\[49\] | In-room intensity director with relax windows |
| Resident Evil 4 (hidden difficulty rank) | Invisible adjustment within fixed bounds | Bounded, invisible, never mid-fight surprises |
| Elo/Glicko/TrueSkill | Rate players *and* content on one scale | Rate each room template/modifier combo from population data |
| Multi-armed bandits (Thompson sampling) | Explore/exploit under uncertainty | Choose among *equal-difficulty* variants to maximize next-session return |
| RL / player modelling | Learn policies from data | Later (v3), offline only, once you have ~1M room logs |
| Guo, Thawonmas & Ren, "Rethinking dynamic difficulty adjustment for video game design" (Entertainment Computing vol. 50, 100663, May 2024) | "DDA should not depend on Flow theory but should be defined based on game difficulty and… designed towards specific design goals" | Our goals: 70–80% clears, ≤2 consecutive deaths, rising mastery |

### 7.2 Telemetry per room (client → `/v1/telemetry`, batched)

Each room sends one batched event with these fields:
- **Identity:** anonymous user ID, theme, room index, seed
- **Room setup:** template, modifiers, wave budget, rating before the room
- **Outcome:** clear, death or quit, plus time to clear
- **Pressure:** damage taken, HP fraction at the end, minimum HP fraction, near-death events
- **Offence:** kills per archetype, shots and hits
- **Choices:** gods used, cages freed out of total
- **Recovery:** retry index and revive type (ad, free or none)
- **Session context:** room index within the session, and whether the app was quit within 30 s

**Rage-quit indicator:** death followed by an app background or quit within 30 s, or 3+ deaths on the same room within 10 minutes.

### 7.3 The model (v1, statistical, fully on-device with server sync)

**Skill estimate.** The player rating is `R` (start 1000). Each generated room gets a difficulty rating `D`, computed from its budget, modifiers and template, and calibrated from population data.

Expected success: `E = 1 / (1 + 10^((D − R)/400))`

Observed performance, as a continuous score in [0, 1]:
`S = 0.55·cleared + 0.25·hp_end_frac + 0.10·(1 − near_death_norm) + 0.10·time_score`

Update: `R ← R + K·(S − E)`. Use K=40 for the first 10 rooms, then 24, with a Glicko-style uncertainty that shrinks K.

**Target 75% success.** Solving `E = 0.75` gives `D_target = R − 191`. Map D to a wave budget with a calibrated linear fit, e.g. `budget = 0.12·D + 20`, re-fit weekly from data.

**Room-level intensity director** (a Left 4 Dead-style state machine):
```
intensity += damage_taken_norm*1.0 + near_death*0.5 + enemies_within_4_tiles*0.05   (per second)
intensity *= 0.97 per second (decay)

   ┌──────── BUILD_UP ────────┐   intensity ≥ 0.8   ┌──── PEAK (≤ 8 s) ────┐
   │ spawn per wave timeline  │ ──────────────────► │ finish current wave, │
   └──────────▲───────────────┘                     │ no new portals       │
              │ intensity < 0.3 & relax ≥ 6 s       └─────────┬────────────┘
              └──────────────── RELAX (6–12 s) ◄──────────────┘
                   no spawns; guaranteed 1 heal/spirit wisp if HP < 35%
```
Target shape within a room: wave 1 builds, wave 2 peaks, a relax window follows, and the final wave (or elite/boss) is the highest peak before the exit opens.

### 7.4 Knobs → parameters

| Knob (ordered: least → most perceptible) | Range | Adjust when |
|---|---|---|
| Healing/spirit wisp drop chance | 2–12% | Between waves |
| Cage count / reward | 0–3 | Room gen |
| Wave spacing (s) | 4–12 | Room gen / relax length |
| Spawn distance from player (tiles) | 6–12 | Room gen |
| Enemy count (budget) | ±25% of baseline | Room gen |
| Mix bias (swarm/tank/ranged) | weights | Room gen |
| Elite chance | 0–20% | Room gen |
| Enemy speed | ±8% max | Arc boundary only |
| Enemy HP/damage | ±10% max | Arc boundary only; **never** for bosses mid-arc |

### 7.5 Safety rails
- [ ] Max change per room: ±1 band, or ±8% budget. Max per arc: ±20%.
- [ ] No adjustment mid-wave. Portal counts are locked once a wave starts.
- [ ] Player-chosen difficulty (Story / Normal / Hunter) shifts the success target (85% / 75% / 60%) and hard-clamps D. DDA never overrides the player's choice.
- [ ] Mercy rule: after 2 deaths in the same room, offer a "Pira scouting" guide (visible and diegetic) and lower the budget by 1 band. After 3 deaths, the next room is guaranteed to be a relief room.
- [ ] Anti-sandbag: rating only drops on deaths with a low damage-dealt ratio and a normal session context, so intentional dying doesn't farm easy rooms.
- [ ] Rewards never shrink when DDA helps. Don't punish struggling players economically.
- [ ] Transparency: settings has "Adaptive challenge: ON/OFF" (default ON).

### 7.6 Tuning and A/B testing
- **Experiment 1:** DDA OFF (static curve) vs DDA ON. Primary metric D7; guardrails D1, rage-quit rate, session length.
- **Experiment 2:** success target 70% vs 75% vs 80%.
- **Experiment 3 (bandit):** Thompson sampling over equal-difficulty variants (template × modifier). Reward = the player starts another room within 24 h.
- Store every room's `(R, D, S, outcome)`. A weekly job re-fits the `D ↔ budget` mapping and flags templates whose realized clear rate is >10 points off prediction.

### 7.7 LLM vs statistical controller

| Job | Better tool |
|---|---|
| Keep success ≈75%, step limits, mercy rules | **Statistical controller** (deterministic, testable, free, offline) |
| Pick among equal-difficulty variants for engagement | **Bandit** |
| Theme-consistent names, whispers, modifier explanations ("The fog thickens because you favoured the dark paths") | **LLM** |
| Summarize player style into a label for narrative ("the Patient Hunter") | LLM (cached) |
| Novel combinations of pre-approved modifiers | LLM, validated |

---

## 8. Backend architecture (FastAPI / Postgres / pgvector / Azure)

**Components:**
- **Client (Godot):** runs DDA, PCG, the fallback planner and a local cache. It talks to the backend over HTTPS with HMAC signing, and to Firebase for analytics, Remote Config and ILRD.
- **Edge:** Azure Front Door in front of Blob Storage, which holds the theme packs and signed manifests.
- **Compute:** Azure Container Apps (move to AKS later if needed), running three services:
  - `api` (FastAPI): `/v1/session`, `/v1/telemetry`, `/v1/plan/next`, `/v1/profile`, `/v1/themes`, `/v1/report`, `/v1/iap/verify`
  - `worker` (arq or Celery): plan pre-generation, DDA refits, rollups
  - `llm-gateway`: routing, caching, budgets, schema validation
- **Data:**
  - Postgres Flexible Server: profiles, ratings, telemetry partitioned by day, pgvector for plan embeddings
  - Azure Cache for Redis: plan cache and rate limits
- **LLM providers:**
  - primary: Gemini Flash-Lite class
  - fallback: Claude Haiku 4.5 or a GPT-mini-class model
  - a batch API for pre-generation

**Key design points:**
- **LLM gateway:** use your own thin router (or LiteLLM) with:
  - per-model timeouts
  - structured output, and failover on a schema failure
  - a response cache keyed by `(theme, skill_band, style_cluster, novelty_bucket)`
  - a **hard daily spend cap**: when it's hit, serve only from the pool
- **Pre-generation pool:** a nightly batch job generates ~200 validated arcs per (theme × 6 skill bands × 8 style clusters). Runtime is then mostly cache hits, and pgvector picks the plan that is most novel for that player.
- **Rate limits:** 1 plan per arc per user, and 30 telemetry batches/hour.
- **Anti-cheat** (single-player, so keep it proportionate):
  - HMAC-signed telemetry with a per-install key
  - plausibility checks (kills/sec, currency deltas)
  - server-side IAP receipt verification (App Store Server API / Play Developer API)
  - Play Integrity / App Attest on `/iap/verify` only
  - leaderboards (if any) are server-validated
- **Privacy (GDPR / India DPDP / US states):**
  - anonymous install UUID, with no name, email or precise location
  - consent flag gates any non-essential telemetry
  - `/v1/profile/delete`, plus a data-export endpoint
  - retention: raw telemetry 90 days, aggregates 2 years
  - Azure Central India region for Indian users
  - privacy policy lists the LLM vendors as processors, and prompts carry no personal data
- **Offline:** the game is fully playable offline. Telemetry is queued (max 500 events) and the planner falls back to local.

### 8.1 Monthly cost model (estimates, USD; verify against current Azure and model pricing)

**Assumptions:**
- 8 rooms/DAU/day, i.e. ~1.6 arcs → 1.6 plan requests/DAU/day
- LLM call ≈ 2,000 input + 600 output tokens
- Gemini 3.1 Flash-Lite at $0.25 / $1.50 per M tokens ≈ **$0.0014/call**\[50\]
- Batch pre-generation at ~50% of that
- Claude Haiku 4.5 ($1 / $5) as fallback ≈ $0.005/call\[50\]\[51\]
- Gemini 2.5 Flash-Lite ($0.10 / $0.40) retires 16 Oct 2026, so don't build on it\[50\]\[52\]

| DAU | Infra (API, Postgres, Redis, CDN, logs) | LLM: naive live (every arc, no cache) | LLM: **recommended** (≥70% pool hits + nightly batch) | Total (recommended) |
|---|---|---|---|---|
| 1k | $40–80 | ~$67 | ~$20 + ~$10 batch = **~$30** | **~$70–110** |
| 10k | $150–300 | ~$670 | ~$200 + ~$15 = **~$215** | **~$365–515** |
| 100k | $800–1,500 | ~$6,700 | ~$2,000 + ~$25 = **~$2,025** | **~$2.8k–3.5k** |

- **Cheaper still:** serve **only** from the pool (0 live calls), and live generation costs nothing. You lose little, because the player can't tell a pool plan from a live one when it's chosen by their profile.
- **Revenue sanity check:** at an assumed India ARPDAU of $0.01–0.02, 10k DAU earns ~$3–6k/month. Keep total AI + infra under ~10% of revenue.

---

## 9. Phased roadmap

### 9.1 Weeks 1–20 (12–15 h/week + Claude)

| Wk | Focus | Deliverables / exit check |
|---|---|---|
| 1 | Project reset | Godot 4.7.2 project, repo layout (`addons/vanya_core`, `themes/`, `data/`), CI export (GitHub Actions headless), Android debug build on device |
| 2 | Archetype data model | `EntityDef`, `CurrencyDef`, `GodDef` Resources; gameplay reads *only* archetype IDs |
| 3 | ThemeRegistry v1 | Manifest loader, UI `Theme` swap, strings per theme; hard-coded 2nd "greybox" theme to prove swapping |
| 4 | Core loop port | Joystick, auto-aim bow, Rotling/Thornback/Wisp, waves, meat/spirit economy |
| 5 | Lighting + rigs | Darkness (CanvasModulate + PointLight2D torches), first cut-out rig from SVG layers |
| 6 | PCG v1 | Chunk templates, validation, fallback rooms, seeds reproducible |
| 7 | Vertical slice | 5 groves + Rotheart boss, camp, gods Meghra/Dhoru/Vayli, save/load. **Milestone M1: fun check with 5 friends** |
| 8 | iOS build | Xcode export on M4 Pro, signing, TestFlight internal; iOS 17 target decision |
| 9 | Telemetry + backend skeleton | FastAPI on Azure Container Apps, Postgres, `/telemetry`, `/session`; Firebase Analytics both platforms |
| 10 | DDA v1 | Rating model, budget mapping, intensity director, safety rails, debug overlay |
| 11 | Ads | Poing v5.1: rewarded revive/double, AdPacer interstitial, UMP, iOS IDFA explainer + ATT, test ads |
| 12 | IAP + Remote Config | godot-iap: Remove Ads, starter pack; server receipt verify; RC flags (ad pacing, DDA target, theme) |
| 13 | Theme pack delivery | PCK export filter (no scripts), CI script check, Blob/CDN, signed manifest, download UI w/ size |
| 14 | Theme #2 real art | One contrasting theme (e.g., underwater or space) via the offline AI→vector pipeline |
| 15 | Meta + guides | Suryak/Tamba/Kaja/Anjor meta upgrades, Pira/Jugnu, meta economy tuning |
| 16 | AI director v1 | `/plan/next`, JSON schema, validation, Python PCG simulator, fallback, prefetch at wave 2 |
| 17 | Pre-gen pool + report button | Nightly batch generation, pgvector novelty, ⚑ report flow, moderation list |
| 18 | Polish + compliance | Data safety form, nutrition labels, privacy manifest reasons, privacy policy (AI processors), age gate, 16 KB check, PBL 8+ check |
| 19 | Closed testing | Play closed track (org account: no 12×14 gate, but still run 20+ testers) + TestFlight external; crash-free ≥99.5% |
| 20 | Creative tests | 3 creatives × 3 themes on Google App campaigns (India, installs), CPP/CSL per theme. **Milestone M2: soft-launch candidate** |

### 9.2 Milestones after week 20

```
W21–26  M3 Soft launch India (Android first, iOS in parallel)  → D1/D7, ARPDAU, crash/ANR
W24–30  M4 Theme feasibility Stage 2 (Remote Config assignment, ~1.5k installs/theme)
W27–32  M5 Tier-1 read: Canada (+ Philippines/Indonesia/Brazil for cheap volume) → LTV ceiling, iOS ATT impact
W30–36  M6 Go/No-Go → global launch or pivot theme / core loop
Post    Live ops: monthly theme "World", DDA v2 (bandits), MAX A/B if ad revenue justifies
```

### 9.3 Go / no-go gates

| Metric | Soft-launch target | Kill / pivot signal |
|---|---|---|
| D1 retention | ≥ 30–35% | < 25% after 2 iterations |
| D7 retention | ≥ 10–12% | < 7% |
| D30 | ≥ 3–4% | < 2% |
| Avg session length | ≥ 8 min; ≥ 2.5 sessions/DAU | < 5 min |
| Rewarded views/DAU | ≥ 1.5 | < 0.7 |
| ARPDAU (India) | ≥ $0.015 (assumption) | < $0.007 |
| Crash-free users / ANR | ≥ 99.5% / below Play's bad-behaviour thresholds | Play vitals warnings |
| DDA health | 70–80% realized clear rate; rage-quit < 5% of deaths | clear rate outside 60–90% |
| Unit economics | Projected D90 LTV ≥ 1.2× blended CPI | LTV < CPI in all markets |

---

## 10. Team and budget

Exchange rate assumed at ₹88 = $1. Figures are planning ranges for Indian freelance markets and need quotes.

| Role | Engagement | INR | USD |
|---|---|---|---|
| Vector illustrator / 2D cut-out animator | Part-time 4–5 months (theme #1 polish + theme #2) | ₹2.0–4.0 L | $2.3–4.5k |
| Sound designer + composer | SFX pack (~60) + 3–4 loops per theme | ₹0.6–1.5 L | $0.7–1.7k |
| QA | Device-lab sessions + testers (Firebase Test Lab / BrowserStack credits) | ₹0.3–0.6 L | $350–700 |
| Backend | You | — | — |
| Localization (Hindi, Marathi) | Per-word freelance | ₹0.2–0.4 L | $230–450 |

| Fixed / tools | Cost |
|---|---|
| Apple Developer Program | $99/yr (~₹8.7k) |
| Google Play registration | $25 one-time (~₹2.2k) |
| Store commission | 15% on the first $1M (Google), and 15% via the Apple Small Business Program (enroll) |
| AI art tools (Scenario/Layer/Leonardo/Recraft) | $30–60/month during production |
| LLM dev and pre-gen | $20–60/month pre-launch |
| Azure infra | $40–100/month to soft launch |
| Claude (coding) | your existing plan |
| **UA: theme feasibility** | 3–4 themes × $300–600 = **$1.2–2.4k (₹1.0–2.1 L)** |
| **UA: soft-launch cohorts** | India $1.5–3k; Canada $1–2k (iOS + Android) |

**Total cash to go/no-go:** roughly **₹6–12 L (~$7–14k)**, most of it art, audio and UA.

---

## 11. Risk register

| # | Risk | Likelihood | Impact | Mitigation | Owner/trigger |
|---|---|---|---|---|---|
| 1 | AI cost blowout | Med | High | Pool-first serving, daily hard cap, cheap model tier, batch pre-gen, alert at 50/80/100% | Spend > $5/day pre-launch |
| 2 | Generated level feels bad or unfair | Med | High | LLM picks enums only; Python sim validation; fallback planner; flag low-rated templates | Room rating < 3.5/5 or clear-rate drift |
| 3 | DDA feels like rubber-banding | Med | High | Supply-side knobs first, step limits, no mid-wave changes, player toggle, mercy rules | Rage-quit > 5% of deaths |
| 4 | App Store rejection (2.5.2 / 4.3 / 5.1.2) | Med | High | Asset-only packs + CI script check; one app; review notes; AI-data disclosure | Any rejection → fix within 48 h |
| 5 | Play policy (AI content, Families, data safety) | Low–Med | High | ⚑ report button, 13+ audience, accurate data safety | Policy email |
| 6 | Godot plugin breakage on engine/SDK updates | Med | Med | Pin versions; upgrade in branch; keep native wrapper fallback; watch Poing/godot-iap releases | New Xcode/SDK or PBL deadline |
| 7 | Content moderation miss (offensive AI text) | Low | High | Curated vocabulary, blocklist, classifier, report pipeline, kill-switch via Remote Config | Any report |
| 8 | Cultural sensitivity (Warli, tribal imagery) | Med | Med | Consult Warli artists/community, credit, avoid sacred motifs as enemies; "enemies" = blight, not people | Before marketing |
| 9 | Low India eCPM → no LTV | High | Med | Tier-1 read in Canada; IAP Worlds; Remove Ads; rewarded-first design | ARPDAU < $0.007 |
| 10 | Scope creep (themes, AI features) | High | High | Only 2 themes before M3; AI director behind flag; weekly scope review | Any week slips > 1 |
| 11 | Founder bandwidth (12–15 h/wk) | High | Med | Claude for code; freelance art early; cut banner/app-open/extra modes | 2 slipped weeks in a row |
| 12 | Minors and DPDP | Med | Med | Age gate, NPA for <18, minimal telemetry, legal review before scale | Before India scale-up |

---

## 12. Caveats
- Plugin versions and dates were current as of late September 2026: Poing v5.1.0 (13 Sep 2026), AppLovin MAX Godot 1.2.0 (Apr 2025), and godot-firebase-ios requiring iOS 17+ and Godot 4.6.1+.\[1\]\[4\] Community plugins can stall, so pin versions and re-check before each release.
- eCPM figures come from vendor benchmark blogs (Playwire, RevenueLab, MonetizeMore, Bidlogic, Tenjin/CAS). They are directional and vary by genre and mediation setup. India figures in the tables marked "assumption" are planning estimates, not measured data.
- ATT opt-in figures differ a lot between vendors because each measures differently. Singular reports 18.58% immediate opt-in for games (Q2 2024), while Adjust reports 39% for gaming (Q1 2026). Measure your own.
- LLM prices change quickly. Gemini 2.5 Flash-Lite retires 16 Oct 2026, so check the providers' pricing pages before committing budgets.
- Infra and art cost ranges are estimates, not quotes. The DPDP guidance is a summary, not legal advice. Get counsel before targeting minors or scaling in India.

## Sources

1. [Releases · poingstudios/godot-admob-plugin](https://github.com/Poing-Studios/godot-admob-editor/releases)
2. [Godot IAP - Cross-Platform In-App Purchases - Godot Asset Library](https://godotengine.org/asset-library/asset/4627)
3. [GitHub - hyochan/godot-iap: In App Purchase plugin for Godot that confirms OpenIAP · GitHub](https://github.com/hyochan/godot-iap)
4. [GitHub - AppLovin/AppLovin-MAX-Godot](https://github.com/AppLovin/AppLovin-MAX-Godot)
5. [4.3 Spam](https://healthycoderblog.wordpress.com/2020/11/10/4-3-spam-a-controversial-app-review-guidelines/)
6. [Godot (game engine)](<https://en.wikipedia.org/wiki/Godot_(game_engine)>)
7. [Releases · godot-sdk-integrations/godot-google-play-billing](https://github.com/godotengine/godot-google-play-billing/releases)
8. [Commits · godot-sdk-integrations/godot-google-play-billing](https://github.com/godot-sdk-integrations/godot-google-play-billing/commits)
9. [Google Play Closed Testing: 12 Testers, 14 Days](https://vmobify.com/blog/google-play-closed-testing-requirement)
10. [Google Play's 12 Testers, 14 Days Requirement Explained: Who It Applies To and How the Clock Really Works (2026)](https://ontest.app/blog/google-play-12-testers-14-days-requirement-explained)
11. [Unity is Canceling the Runtime Fee](https://unity.com/blog/unity-is-canceling-the-runtime-fee)
12. [Unity in 2026: The State of the Engine After the Runtime Fee Aftermath](https://www.strayspark.studio/blog/unity-engine-2026-state-comeback-runtime-fee-aftermath)
13. <https://poingstudios.github.io/godot-admob-plugin/privacy/user_messaging_tools/idfa_support/>
14. [GitHub - cengiz-pz/godot-ios-admob-plugin: Godot iOS Admob Plugin allows Godot apps access to Google Mobile Ads SDK on the iOS platform. · GitHub](https://github.com/cengiz-pz/godot-ios-admob-plugin)
15. [GitHub - godot-sdk-integrations/godot-admob: A Godot plugin that provides a unified GDScript interface for integrating Google Mobile Ads SDK on Android and iOS. · GitHub](https://github.com/godot-sdk-integrations/godot-admob)
16. [GitHub - poingstudios/godot-att-ios: App Tracking Transparency Godot Framework · GitHub](https://github.com/poingstudios/godot-att-ios)
17. [GitHub - godot-sdk-integrations/godot-storekit2: iOS plugin for Godot integrating the StoreKit 2 API · GitHub](https://github.com/godot-sdk-integrations/godot-storekit2)
18. [GitHub - SomniGameStudios/godot-firebase-ios · GitHub](https://github.com/SomniGameStudios/godot-firebase-ios)
19. [iOS new required API usage declarations: NSPrivacyAccessedAPICategorySystemBootTime NSPrivacyAccessedAPICategoryFileTimestamp NSPrivacyAccessedAPICategoryDiskSpace · Issue #90323 · godotengine/godot](https://github.com/godotengine/godot/issues/90323)
20. [EditorExportPlatformIOS — Godot Engine (stable) documentation in English](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformios.html)
21. [EditorExportPlatformIOS — Godot Engine (4.4) documentation in English](https://docs.godotengine.org/en/4.4/classes/class_editorexportplatformios.html)
22. [Exporting for iOS — Godot Engine (stable) documentation in English](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
23. [Android 16 (API Level 36) Target SDK Requirement: What You Need to Do Before August 31](https://www.appsonair.com/blogs/android-16-api-level-36-target-sdk-requirement-what-you-need-to-do-before-august-31)
24. [Target API level 36: your Google Play extension ends 1 November](https://creuto.com/target-api-level-36-google-play-deadline)
25. [Target API Level 36 (Android 16) - August 31, 2026 Deadline: Submission and Availability Requirements](https://kapps.store/faq/target-api-level-36-android-16-august-31-2026-deadline-submission-and-availabili.html)
26. [Google Play Billing Library version deprecation](https://developer.android.com/google/play/billing/deprecation-faq)
27. [Google Play 20 to 12 Testers: 2026 Closed Testing Rule](https://primetestlab.com/blog/google-play-changed-20-to-12-testers)
28. [Developer Programme Policy - Play Console Help](https://support.google.com/googleplay/android-developer/answer/16944162?hl=en-IN)
29. [iOS SDK - Privacy manifest FAQ](https://support.singular.net/hc/en-us/articles/24045392537243-iOS-SDK-Privacy-manifest-FAQ)
30. [App Review Guidelines - Apple Developer](https://developer.apple.com/app-store/review/guidelines/)
31. [Exporting packs, patches, and mods — Godot Engine (stable) documentation in English](https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html)
32. [How to Fix a Godot .pck Mod Pack That Doesn't Override Base Game Files](https://bugnet.io/blog/how-to-fix-godot-pck-mod-pack-not-overriding-base-game-files)
33. [Apple Updates App Store Guidelines With Stricter Rules for Low-Quality Apps - MacRumors](https://www.macrumors.com/2026/06/09/app-store-guidelines-low-quality-apps/)
34. [Spam - Play Console Help](https://support.google.com/googleplay/android-developer/answer/9899034?hl=en-GB)
35. [Complete Guide to Custom Product Pages 2026](https://theapplaunchpad.com/blog/guide-to-custom-product-pages/)
36. [App Store Custom Product Pages: A Practical 2026 Guide for Indie Teams](https://www.applaunchflow.com/blog/app-store-custom-product-pages-guide)
37. [App Store product page optimization: how to run A/B tests (2026)](https://www.mobileaction.co/blog/product-page-optimization/)
38. [Ad Monetization in Mobile Games](https://tenjin.com/blog/ad-mon-gaming-2026/)
39. [GitHub - MrZak-dev/godot-ironsource-android-plugin · GitHub](https://github.com/MrZak-dev/godot-ironsource-android-plugin)
40. [Is there a way to use unity ads into godot? - Help - Godot Forum](https://forum.godotengine.org/t/is-there-a-way-to-use-unity-ads-into-godot/95369)
41. [AdMob eCPM Benchmarks: What Publishers Should Expect](https://www.playwire.com/blog/admob-ecpm-benchmarks-what-publishers-should-expect)
42. [AdMob eCPM Benchmarks 2026: Rewarded, Interstitial, Banner — by Format, Geo, and OS](https://www.revenuelab.fyi/blog/admob-ecpm-benchmarks-2026)
43. [Q2 2026 eCPM growth: Interstitial, Rewarded Video and Banner trends](https://bidlogic.io/2026/07/31/q2-2026-ecpm-growth-interstitial-rewarded-video-and-banner-trends/)
44. [2026 eCPM Insights you Missed Out On! (What Ad Format Earns the Most?) - MonetizeMore](https://www.monetizemore.com/blog/ecpm-insights/)
45. [Google Play Store icon](https://techcrunch.com/?p=2619733)
46. [The case for dynamic difficulty adjustment in games](https://dl.acm.org/doi/10.1145/1178477.1178573)
47. [Dynamic Difficulty Adjustment (DDA) in Computer Games: A Review - Zohaib - 2018 - Advances in Human-Computer Interaction - Wiley Online Library](https://onlinelibrary.wiley.com/doi/10.1155/2018/5681652)
48. [Connect Via Articles Broadcasts Forums Premium Plus My Profile Logout Search...](https://www.cs.drexel.edu/~so367/teaching/2012/CS680/papers/11%20Secrets%20about%20LEFT%204%20DEAD%e2%80%99s%20AI%20Director%20and%20its%20Procedural%20Zombie%20Population%20%7c%20AiGameDev.com.pdf)
49. [How to Build a Stalker System for Your Game](https://medium.com/@armoury_ale_0s/how-to-build-a-stalker-system-for-your-game-77ad2babb127)
50. [Google Gemini API Pricing Guide 2026: Flash, Pro, and Vertex AI](https://curlscape.com/blog/google-gemini-api-pricing-guide-2026)
51. [Gemini Flash Lite vs GPT-4o Mini vs Claude Haiku (2026) - Macaron](https://macaron.im/blog/gemini-flash-lite-vs-gpt4o-mini-vs-claude-haiku)
52. [Google Vertex AI pricing in 2026: Gemini API rates, every model, and what it really costs](https://www.cloudzero.com/blog/google-vertex-ai-pricing/)
