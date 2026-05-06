# Demo Data

Buylog uses one deterministic demo user for manual QA and screen demos:

- User id: `00000000-0000-4000-8000-000000000101`
- Email: `demo.user+buylog@example.com`
- Display name: `사용자`

The curated Supabase demo dataset is intentionally small:

- 7 household consumables
- 27 purchase records
- Relative purchase dates based on `current_date`
- Realistic store names and prices

Curated products:

- `정수기 필터` / `코웨이`: high-priority filter replacement
- `주방 세제` / `자연퐁`: frequent kitchen consumable
- `세탁 세제` / `퍼실`: medium-cycle laundry item
- `화장지` / `코디`: common bulk household purchase
- `치약` / `덴티스테`: slower hygiene cycle
- `샴푸` / `케라시스`: personal-care item
- `샤워기 필터` / `바디럽`: second filter item with a longer cycle

The seed is scoped to the deterministic demo user. Do not broaden cleanup SQL to all users or all purchases.

When changing demo data, keep these screens in mind:

- Home: replacement urgency and recent records
- Items: product list and detail
- Reports: monthly spend aggregation
- Settings/group screens: neutral user naming
