---
status: draft
updated: 2026-11-18
---

# Vegabase: Glossary

## Terms

**Access policy**: A per-visitor gate that serves its page kind on protected routes until the visitor passes the policy's verify action. Passing gives the session a grant scoped to tenant, policy, policy version and expiry. _Avoid:_ password page, age gate (these are uses).

**Action**: A typed, authorized, idempotent write a visitor triggers. Components re-render from its committed result. _Avoid:_ mutation endpoint, form post, handler.

**Activate**: Make a deployment the one served for a tenant by moving its activation pointer. _Avoid:_ go live, publish, ship, release.

**Admin**: A person who uses the admin app to approve plugins and manage users and domains; a separate role from editor. _Avoid:_ owner, superuser.

**Cache class**: How a component's output is served: **shell** (CDN, tagged by read set), **cached fragment** (CDN, signed, `s-maxage`), **on-demand fragment** (rendered by the owning worker from cached fields), **live** (rendered by the owning worker, fields fetched every render). How a component declares it is open (lang Q-11). _Avoid:_ freshness level.

**CDN**: The third-party cache in front of origin that serves public shells, cached fragments and assets. Never a security boundary. "Edge cache" means the same thing. _Avoid:_ public cache.

**Component**: A `component` declaration plus the one template that names it; placeable in slots, identified by its name, with the plugin's prefix when a plugin ships it, never by its path (VEGA §5). _Avoid:_ snippet, partial.

**Component replacement**: A theme's explicit declaration that its component takes the place of a plugin component with the same fields and props (syntax: Q-045). Not in the first edition (lang D-64). _Avoid:_ override, theme override.

**Composition**: An editor-saved arrangement of components in slots, with field values, served on a route. _Avoid:_ page, page config, JSON template.

**Computed field**: A field derived from other fields, recomputed when any input changes. _Avoid:_ derived field, virtual field.

**Content type**: The shape of a thing an editor creates many of and does not place on a page, such as a blog post or a recipe; declared with `content` by a theme or a plugin (VEGA §8). _Avoid:_ collection, model.

**Context**: The dimension values (market, language, currency, channel, customer, B2B company location) a read is keyed by and a field may vary by. _Avoid:_ request context, locale. Odin's `context` is always in code font.

**Contract**: The edition-pinned declaration of a published field, owned entity type or event that other extensions may depend on, as required or optional. _Avoid:_ interface, API.

**Control plane**: The platform-wide service on Postgres that holds tenants, domains, ownership, the activation pointer, gates, enablement and approvals, and propagates versioned changes. _Avoid:_ master, orchestrator.

**Core**: The closed, domain-agnostic engine and its data layer, with no commerce concepts. Excludes the language toolchain. _Avoid:_ platform, framework, kernel.

**Customer**: A visitor logged in to a store's customer account. _Avoid:_ buyer, user, account.

**Data need**: A prop filled by a loader: a typed value the data layer resolves through a declared loader, bound to one source role (VEGA §7). _Avoid:_ query, data binding.

**Deployment**: An immutable, versioned snapshot of a tenant's theme and its compiled plans, validated before it can be activated. _Avoid:_ build, release, theme version.

**Edge**: The CDN plus our front routers: everything between the visitor and the owning worker. _Avoid:_ gateway.

**Edition**: A versioned release of the spec: the `.vega` language, transforms, contracts, vendor interface, plugin ABI and theme format. The current and previous editions are the **supported editions**. _Avoid:_ spec version, live edition.

**Editor**: A person who uses the admin app to manage routes, compositions and content, and never writes code or wires data. _Avoid:_ merchant user, content author.

**Engine release**: A versioned build of the core binary (`1.0.0-alpha.N` until 1.0.0). Independent of editions and deployments; each release declares the editions it supports (D-023). _Avoid:_ version (alone), build.

**Entity**: Shared, durable data with a type and a canonical ID, such as a product or blog post. Its type is a plugin type, such as `shopify.Product`, or a content type. _Avoid:_ record, object, resource, document.

**Extension**: A plugin of either kind: a vendor lib or a sandboxed plugin. The core is not an extension. _Avoid:_ app, add-on, integration, module.

**Fallback view**: What the origin serves when something can't be rendered: a stale value or a minimal built-in page. Never a 5xx page (D-018). Whether a component can declare its own unavailable state is open (lang Q-11). _Avoid:_ error page.

**Fencing**: Rejecting a write whose generation is older than the tenant's current one, so only the owning worker writes (D-018). _Avoid:_ locking.

**Fetch plan**: The merged fields, per entity type and context, that a deployment's components and compositions need, computed at deploy or save. _Avoid:_ query plan, data plan.

**Fragment**: The HTML of one component instance, re-rendered on its own through a signed endpoint and morphed into place by instance ID. _Avoid:_ partial, island, widget.

**Freshness window / staleness limit**: How long a value counts as fresh, and the hard limit after which a stale value may not be served. _Avoid:_ TTL (that's a cache setting).

**Front router**: Our stateless proxy (libh2o, one per host) that verifies the tenant, normalizes the host and forwards to the owning worker. _Avoid:_ load balancer.

**Gate**: An override or access policy that keeps visitors from a page. Gates fail closed. _Avoid:_ readiness gate.

**Group**: A named union of components that a slot accepts (VEGA §4.3). _Avoid:_ kind, component type.

**Language toolchain**: The `.vega` compiler front-end, type checker, LSP and plugin SDK; built separately from core and distributable as signed binaries (D-012). _Avoid:_ compiler (alone), CLI.

**Lease / generation**: The time-bound grant and ever-increasing number under which a worker owns a tenant. Stale generations are rejected. _Avoid:_ lock, epoch.

**Merchant**: The business that runs a store. _Avoid:_ client, shop owner.

**Origin budget**: The maximum origin requests per second one owning worker may take for a tenant. A deployment above it fails its readiness check. _Avoid:_ capacity.

**Override**: A tenant-wide rule that serves a page kind and status on given routes, optionally between a start and end time. _Avoid:_ route override, component override.

**Owning worker**: The one worker that, under a lease and generation, holds a tenant's database, caches, read index and open streams. _Avoid:_ owner, home worker, shard, host.

**Page**: The HTML a visitor receives for a URL: a shell plus fragments. _Avoid:_ "page" for a composition or a fixed page.

**Page kind**: The role of a page: **fixed page** (served at editor-set URLs), **entity** (its URL names a subject, which a plugin's kind of page supplies as a `$` value, lang D-52), **not-found** (an ordinary admin page, lang D-38), or a plugin page kind served only through gates (Q-046). Pages are defined in the admin app, never in code (lang D-13). _Avoid:_ template type, static page.

**PII class**: A field's or storage entry's personal-data class, which drives scope approval, filtering and erasure. _Avoid:_ sensitivity.

**Plugin**: An extension. It has a prefix and may ship `.vega` files (VEGA §10). A first-party plugin is a **vendor lib**. Any other is a **sandboxed plugin**: untrusted, run in WASM with admin-approved capabilities. Its code never renders HTML and supplies no function a template calls; the core renders its templates (lang D-67). _Avoid:_ app, add-on, WASM module (its build output).

**Prefix**: The library name in front of a name: `std` for the core, or a plugin's name, as in `shopify.Product`. A name the theme declares has no prefix (VEGA §2). _Avoid:_ owner, package, module.

**Published field**: A field an extension writes onto an entity type it does not own, under a contract. _Avoid:_ metafield, extension field.

**Read index**: A tenant's local store of the shared entities and context projections its fetch plans need; renders read it instead of upstream. _Avoid:_ mirror, local copy, search index.

**Read set**: The entities, fields and list queries one render read; used for CDN tags and push matching. _Avoid:_ dependencies.

**Readiness check**: The rule that a deployment activates only after its required fields are in the read index and it fits the origin budget. _Avoid:_ readiness gate.

**Route**: An editor-managed URL or URL pattern that maps to a page kind and a composition. Managed in the admin app, never in code (lang D-13). _Avoid:_ template, path (a path is one URL).

**Shell**: The cacheable, non-personalized HTML frame of a page, into which fragments are placed. _Avoid:_ layout, skeleton.

**Slot**: A field marked `slot` where editors place child components, limited by its union and count; depth is capped by the core (VEGA §6.1). _Avoid:_ region, zone, container.

**Source role**: Where a data need's input comes from: the page (a `$` value), site-wide data (a loader with no input, such as `std.siteSettings()`), or an editor's pick (a picker field) (VEGA §6, §7). _Avoid:_ data source, binding.

**Storage class**: A field's sharing class: **shared** (may enter read index, shared cache and CDN) or **private** (per customer or authorization, never shared). How a value is marked private is open (lang Q-41). _Avoid:_ visibility.

**Store**: A tenant that sells through a commerce vendor lib (Shopify; Medusa later). _Avoid:_ shop, storefront; never "store" for a database.

**Tenant**: One hosted site with its own domains, data, theme and deployments: a store or a non-commerce site. _Avoid:_ site, client, account, instance.

**Theme**: A tenant's typed component library, with locales and assets. It declares components, content types and data needs, but no loaders, functions or routes (lang D-13, D-64). _Avoid:_ template, skin.

**Transform**: A function a template calls, supplied by the core or a vendor lib, never by a sandboxed plugin (VEGA §10). _Avoid:_ filter, helper.

**Type owner**: The one extension that provides an entity type's schema, batch resolver, change feed and reconciliation. Who owns a theme's content type is open (VEGA §8). _Avoid:_ owner, provider, source.

**Vegabase**: The project and product name. The file extension is `.vega` (D-033).

**Vendor lib**: A first-party plugin: a trusted native extension built and signed by the platform team, loaded only in workers whose tenants enable it. Shopify is one (lang D-66, D-67). _Avoid:_ native plugin, app, integration.

**Visitor**: Anyone requesting pages from a tenant, logged in or not. _Avoid:_ shopper, user, guest.

**Worker**: A supervised Vegabase process that owns tenants. A **shared worker** hosts many tenants; a **dedicated worker** hosts one. _Avoid:_ instance, node.

## Relationships

- Every store is a tenant; every customer is a visitor on a store.
- Each tenant has exactly one owning worker at a time; a new generation replaces the old.
- Each entity type has exactly one type owner; any extension may publish fields onto it.
- Every page is a shell plus fragments; every component instance can be re-rendered as a fragment.
- Exactly two editions are supported at any time.
- Extensions share only through published fields, owned entity types and events.

## Ambiguous words

- **owner**: owning worker or type owner. Never bare. A library name in front of a type is a prefix.
- **live**: the cache class. Say "supported edition" or "activate" for the other senses.
- **override**: the gate rule. Say "component replacement" for the theme sense.
- **page**: the HTML. Not a composition or the fixed page kind.
- **store**: a selling tenant. Say "database" (StardustDB database, Postgres) for storage.
- **instance**: a component instance only. Say "shared/dedicated worker" for processes.
- **version**: always qualify (engine release, edition, deployment, entity source version, policy, Shopify API version).
- **plugin**: any extension. Say "vendor lib" for the first-party kind and "sandboxed plugin" when only the WASM kind is meant.
- **app / admin**: a Shopify app, or our "admin app". Say "extension" for ours and "Shopify Admin API" in full.
- **template**: a component's template file. Shopify's JSON template maps to route + composition.
- **publish**: an extension writing a published field or event. Say "activate" for deployments.
