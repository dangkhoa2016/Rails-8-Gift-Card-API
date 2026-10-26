/* Vue 3 global CDN app. No npm, bundler, or build step. */
(() => {
  "use strict";

  if (!window.Vue || !window.Vue.createApp) {
    document.getElementById("app").textContent = "Vue CDN could not load. Check connectivity to cdn.jsdelivr.net.";
    return;
  }

  const apiRoot = "/api/v1/";
  const sections = {
    overview: ["Overview", "Role-scoped workflows and architecture"],
    brands: ["Brands", "Create and manage the brand catalog"],
    products: ["Products", "Configure face value, currency, and availability"],
    clients: ["Clients", "Manage accounts and payout rates"],
    grants: ["Product access", "Manage a client’s gift card product permissions"],
    catalog: ["Catalog", "Products your account is authorized to issue"],
    issue: ["Issue gift card", "Create a card safely with an idempotency key"],
    cards: ["My cards", "Inspect and cancel issued cards"],
    reports: ["Financial reports", "Event-time financial activity in original currencies"],
    audit: ["Audit logs", "Inspect request and mutation history"],
    console: ["API console", "Send and inspect raw same-origin HTTP requests"]
  };
  const adminMenu = [
    { id: "brands", icon: "▦", text: "Brands" },
    { id: "products", icon: "▤", text: "Products" },
    { id: "clients", icon: "◉", text: "Clients" },
    { id: "grants", icon: "◇", text: "Product access" },
    { id: "reports", icon: "↗", text: "Reports" },
    { id: "audit", icon: "≡", text: "Audit logs" }
  ];
  const clientMenu = [
    { id: "catalog", icon: "▦", text: "Catalog" },
    { id: "issue", icon: "◇", text: "Issue card" },
    { id: "cards", icon: "▤", text: "My cards" },
    { id: "reports", icon: "↗", text: "Spending" }
  ];

  // Only real Rails routes. Role-specific examples are discoverable without
  // exposing protected Admin endpoints or submitting an HTTP request.
  const consoleTemplateCatalog = {
    admin: [
      { id: "admin-brands", group: "read", label: "List brands",
        method: "GET", path: "/api/v1/admin/brands?page=1&per_page=25",
        note: "Browse Brands with server-side pagination." },
      { id: "admin-brand", group: "read", label: "Show a brand by ID",
        method: "GET", path: "/api/v1/admin/brands/:brand_id",
        note: "Replace :brand_id with a real ID from List brands." },
      { id: "admin-products", group: "read", label: "List products for a brand",
        method: "GET", path: "/api/v1/admin/brands/:brand_id/products?page=1&per_page=25",
        note: "Replace :brand_id with an existing Brand ID." },
      { id: "admin-product", group: "read", label: "Show a product by ID",
        method: "GET", path: "/api/v1/admin/products/:product_id",
        note: "Replace :product_id with a real Product ID." },
      { id: "admin-clients", group: "read", label: "List client accounts",
        method: "GET", path: "/api/v1/admin/clients?page=1&per_page=25",
        note: "List Clients and their IDs without changing data." },
      { id: "admin-client", group: "read", label: "Show a client by ID",
        method: "GET", path: "/api/v1/admin/clients/:client_id",
        note: "Replace :client_id with a real Client ID." },
      { id: "admin-grants", group: "read", label: "List a client's product access",
        method: "GET", path: "/api/v1/admin/clients/:client_id/product_accesses?page=1&per_page=25",
        note: "Replace :client_id to inspect that Client's granted Products." },
      { id: "admin-report-brand", group: "read", label: "Financial report · By brand",
        method: "GET", path: "/api/v1/admin/reports/by_brand",
        note: "Financial activity by Brand and original currency; optional from/to UTC dates." },
      { id: "admin-report-client", group: "read", label: "Financial report · By client",
        method: "GET", path: "/api/v1/admin/reports/by_client",
        note: "Financial activity by Client and original currency." },
      { id: "admin-report-cards", group: "read", label: "Report evidence · Issued Cards by brand",
        method: "GET", path: "/api/v1/admin/reports/cards?group_by=brand&brand_id=:brand_id&currency=USD&event=issued&page=1&per_page=10",
        note: "Replace :brand_id; event-time Card list is read-only and paginated." },
      { id: "admin-audit", group: "read", label: "Audit log · Recent activity",
        method: "GET", path: "/api/v1/admin/audit_logs?page=1&per_page=25",
        note: "Inspect audit history, newest first." },
      { id: "admin-create-brand", group: "write", label: "Create a brand",
        method: "POST", path: "/api/v1/admin/brands",
        body: { name: "REPLACE_WITH_UNIQUE_BRAND_NAME", state: "active" },
        note: "Creates a real Brand and a new audit event. Replace the sample name." },
      { id: "admin-update-brand", group: "write", label: "Update a brand",
        method: "PATCH", path: "/api/v1/admin/brands/:brand_id",
        body: { state: "inactive" },
        note: "Changes the state of a real Brand. Replace :brand_id." },
      { id: "admin-create-product", group: "write", label: "Create a product under a brand",
        method: "POST", path: "/api/v1/admin/brands/:brand_id/products",
        body: { name: "Reviewer Sample Gift Card", face_value: "100.00", currency: "USD" },
        note: "Creates a real Product. Replace :brand_id first." },
      { id: "admin-grant-access", group: "write", label: "Grant a product to a client",
        method: "POST", path: "/api/v1/admin/clients/:client_id/product_accesses",
        body: { product_id: "REPLACE_WITH_PRODUCT_ID" },
        note: "Creates an access grant. Replace the Client and Product IDs first." },
      { id: "admin-soft-delete", group: "write", label: "Soft-delete a product",
        method: "DELETE", path: "/api/v1/admin/products/:product_id",
        note: "Changes the Product to inactive/deleted. Replace :product_id carefully." }
    ],
    client: [
      { id: "client-catalog", group: "read", label: "List eligible products · Catalog",
        method: "GET", path: "/api/v1/client/catalog",
        note: "Start here to discover eligible Product IDs for issuing Cards." },
      { id: "client-catalog-filter", group: "read", label: "Catalog · USD products",
        method: "GET", path: "/api/v1/client/catalog?currency=USD",
        note: "Filter the Client's eligible Catalog by currency." },
      { id: "client-cards", group: "read", label: "List my cards · Paginated",
        method: "GET", path: "/api/v1/client/cards?page=1&per_page=25",
        note: "See your own Cards, including IDs for detail requests." },
      { id: "client-cards-filter", group: "read", label: "My cards · Issued with PIN",
        method: "GET", path: "/api/v1/client/cards?status=issued&has_pin=true&per_page=25",
        note: "Filters Card metadata only; no PIN is returned." },
      { id: "client-card", group: "read", label: "Show one of my cards",
        method: "GET", path: "/api/v1/client/cards/:card_id",
        note: "Replace :card_id with an ID from List my cards; ownership is enforced." },
      { id: "client-spending", group: "read", label: "Personal spending · By currency",
        method: "GET", path: "/api/v1/client/reports/spending",
        note: "Your own issuance and cancellation activity grouped by currency." },
      { id: "client-spending-brand", group: "read", label: "Personal spending · By brand",
        method: "GET", path: "/api/v1/client/reports/spending?group_by=brand",
        note: "Group your Card events by Brand without seeing other Clients." },
      { id: "client-report-cards", group: "read", label: "Report evidence · EUR issued Cards",
        method: "GET", path: "/api/v1/client/reports/cards?currency=EUR&event=issued&page=1&per_page=10",
        note: "Read-only event-time Cards behind the EUR issuance count." },
      { id: "client-issue", group: "write", label: "Issue a gift card",
        method: "POST", path: "/api/v1/client/cards",
        body: { product_id: "REPLACE_WITH_ELIGIBLE_PRODUCT_ID", with_pin: false },
        uniqueKey: true,
        note: "Issues a real Card. Use an eligible Product ID from Catalog and the generated Idempotency-Key." },
      { id: "client-cancel", group: "write", label: "Cancel one of my cards",
        method: "POST", path: "/api/v1/client/cards/:card_id/cancel",
        note: "Cancels a real issued Card. Replace :card_id with your own Card ID." }
    ]
  };

  const app = window.Vue.createApp({
    data() {
      return {
        tab: "overview", session: null, busy: false,
        showBackToTop: false,
        loadingTable: false, loadingDetail: false, submitting: false,
        flash: { text: "", kind: "success" },
        validationErrors: [], lastApiError: null, errorModalOpen: false,
        loginForm: { email: "", password: "" },
        brands: [], products: [], clients: [], grants: [], catalog: [], issueCatalog: [], cards: [], audits: [],
        brandId: "", clientId: "", cardStatus: "", cardPinFilter: "", cardQuery: "",
        cardPage: 1, cardPerPage: 25, cardTotal: 0, cardSortBy: "", cardSortDir: "asc",
        productPage: 1, productPerPage: 25, productTotal: 0,
        productCatalogPreview: false,
        brandPage: 1, brandPerPage: 25, brandTotal: 0,
        clientPage: 1, clientPerPage: 25, clientTotal: 0,
        auditPage: 1, auditPerPage: 25, auditTotal: 0, auditAppliedFilters: {},
        directoryModalKind: null, directoryModalRecord: null,
        directoryModalTrigger: null, directoryModalPreviousOverflow: "",
        accessClientQuery: "", accessPickerOpen: false, accessProductQuery: "", accessGrantQuery: "",
        editingBrandId: null, editingProductId: null, editingClientId: null,
        selectedDetail: null, cardDetail: null, cardModalOpen: false, cardModalTrigger: null,
        cardModalPreviousOverflow: "", catalogQuery: "", catalogCurrency: "",
        catalogBrandId: "",
        brandForm: { name: "", state: "active", custom_fields: "{}" },
        productForm: { brand_id: "", name: "", face_value: "100.00", currency: "USD", state: "active", custom_fields: "{}" },
        clientForm: { email: "", password: "", payout_rate: "90", active: true },
        issueForm: { product_id: "", key: "", with_pin: false },
        issueProductQuery: "", issued: null, issuedHttpStatus: null,
        issuedPinVisible: false, issuedPinTimer: null,
        revealedCardPin: "", revealedCardPinTimer: null, pinRevealError: "",
        reportFrom: "", reportTo: "", reportGroup: "by_brand", reportClientGroup: "currency",
        reportData: null,
        reportPreset: "all", reportCurrencyFilter: "all",
        reportAppliedFrom: "", reportAppliedTo: "",
        reportDrilldownOpen: false, reportDrilldownTrigger: null,
        reportDrilldownOverflow: "", reportDrilldownSelection: null,
        reportDrilldownRows: [], reportDrilldownPage: 1,
        reportDrilldownPerPage: 10, reportDrilldownTotal: 0,
        auditAction: "", auditActor: "", auditOutcome: "", auditFrom: "", auditTo: "",
        consoleTemplateId: "",
        consoleForm: { method: "GET", path: "/api/v1/client/catalog", body: "", key: "" },
        response: { method: "", path: "", body: { message: "Send a request to inspect the response." }, status: null, duration: "—" }
      };
    },
    computed: {
      menu() {
        if (!this.session) return [];
        return [{ id: "overview", icon: "⌂", text: "Overview" },
          ...(this.session.user.role === "admin" ? adminMenu : clientMenu),
          { id: "console", icon: ">_", text: "API console" }];
      },
      consoleTemplateGroups() {
        const examples = consoleTemplateCatalog[this.session?.user?.role] || [];
        return [
          { label: "Read-only examples · Safe to explore", items: examples.filter(t => t.group === "read") },
          { label: "Write operations · Changes real data", items: examples.filter(t => t.group === "write") }
        ];
      },
      selectedConsoleTemplate() {
        return this.consoleTemplateGroups.flatMap(group => group.items)
          .find(t => t.id === this.consoleTemplateId) || null;
      },
      consoleHasPlaceholders() {
        return /:[a-z_]+(?=[/?&]|$)/i.test(this.consoleForm.path) ||
          /REPLACE_WITH_[A-Z_]+/.test(this.consoleForm.body);
      },
      heading() { return sections[this.tab][0]; },
      hint() { return sections[this.tab][1]; },
      selectedIssueProduct() {
        return this.issueCatalog.find(p => p.id === Number(this.issueForm.product_id)) || null;
      },
      matchingIssueProducts() {
        const q = this.issueProductQuery.trim().toLowerCase();
        return this.issueCatalog.filter(p => [p.name, p.brand_name, p.currency, p.face_value]
          .some(value => String(value || "").toLowerCase().includes(q)));
      },
      brandPageCount() { return Math.max(1, Math.ceil(this.brandTotal / this.brandPerPage)); },
      brandFirst() { return this.brandTotal ? (this.brandPage - 1) * this.brandPerPage + 1 : 0; },
      brandLast() { return Math.min(this.brandPage * this.brandPerPage, this.brandTotal); },
      brandVisiblePages() { return this.listVisiblePages(this.brandPage, this.brandPageCount); },
      clientPageCount() { return Math.max(1, Math.ceil(this.clientTotal / this.clientPerPage)); },
      clientFirst() { return this.clientTotal ? (this.clientPage - 1) * this.clientPerPage + 1 : 0; },
      clientLast() { return Math.min(this.clientPage * this.clientPerPage, this.clientTotal); },
      clientVisiblePages() { return this.listVisiblePages(this.clientPage, this.clientPageCount); },
      auditPageCount() { return Math.max(1, Math.ceil(this.auditTotal / this.auditPerPage)); },
      auditFirst() { return this.auditTotal ? (this.auditPage - 1) * this.auditPerPage + 1 : 0; },
      auditLast() { return Math.min(this.auditPage * this.auditPerPage, this.auditTotal); },
      auditVisiblePages() { return this.listVisiblePages(this.auditPage, this.auditPageCount); },
      productPageCount() { return Math.max(1, Math.ceil(this.productTotal / this.productPerPage)); },
      productFirst() { return this.productTotal ? (this.productPage - 1) * this.productPerPage + 1 : 0; },
      productLast() { return Math.min(this.productPage * this.productPerPage, this.productTotal); },
      productVisiblePages() {
        const first = Math.max(1, Math.min(this.productPage - 2, this.productPageCount - 4));
        return Array.from({ length: Math.min(5, this.productPageCount) }, (_, i) => first + i);
      },
      cardPageCount() { return Math.max(1, Math.ceil(this.cardTotal / this.cardPerPage)); },
      cardFirst() { return this.cardTotal ? (this.cardPage - 1) * this.cardPerPage + 1 : 0; },
      cardLast() { return Math.min(this.cardPage * this.cardPerPage, this.cardTotal); },
      cardVisiblePages() {
        const first = Math.max(1, Math.min(this.cardPage - 2, this.cardPageCount - 4));
        return Array.from({ length: Math.min(5, this.cardPageCount) }, (_, i) => first + i);
      },
      reportDrilldownPageCount() {
        return Math.max(1, Math.ceil(this.reportDrilldownTotal / this.reportDrilldownPerPage));
      },
      reportDrilldownFirst() {
        return this.reportDrilldownTotal
          ? (this.reportDrilldownPage - 1) * this.reportDrilldownPerPage + 1 : 0;
      },
      reportDrilldownLast() {
        return Math.min(this.reportDrilldownPage * this.reportDrilldownPerPage, this.reportDrilldownTotal);
      },
      reportRows() { return Array.isArray(this.reportData?.data) ? this.reportData.data : []; },
      reportCurrencies() {
        return [...new Set(this.reportRows.map(row => row.currency))].sort();
      },
      reportVisibleRows() {
        return this.reportCurrencyFilter === "all" ? this.reportRows
          : this.reportRows.filter(row => row.currency === this.reportCurrencyFilter);
      },
      reportIssuedCount() {
        return this.reportVisibleRows.reduce((total, row) => total + Number(row.issued_count || 0), 0);
      },
      reportCancelledCount() {
        return this.reportVisibleRows.reduce((total, row) => total + Number(row.cancelled_count || 0), 0);
      },
      reportCurrencySummaries() {
        // Money remains separated by currency; no implicit FX conversion.
        // Whole cents as BigInt retain the exact API decimal snapshots.
        const totals = new Map();
        for (const row of this.reportVisibleRows) {
          if (!totals.has(row.currency)) totals.set(row.currency, {
            currency: row.currency, issued: 0n, cancelled: 0n, net: 0n, netPayout: 0n
          });
          const entry = totals.get(row.currency);
          entry.issued += this.reportCents(row.issued_face_value);
          entry.cancelled += this.reportCents(row.cancelled_face_value);
          entry.net += this.reportCents(row.net_spending);
          entry.netPayout += this.reportCents(row.net_payout_activity);
        }
        return [...totals.values()].sort((a, b) => a.currency.localeCompare(b.currency));
      },
      reportRangeLabel() {
        if (!this.reportAppliedFrom && !this.reportAppliedTo) return "All recorded activity · UTC";
        return (this.reportAppliedFrom || "Beginning") + " → " +
          (this.reportAppliedTo || "Present") + " (end excluded, UTC)";
      },
      accessClient() { return this.clients.find(c => c.id === Number(this.clientId)) || null; },
      matchingAccessClients() {
        const q = this.accessClientQuery.trim().toLowerCase();
        return this.clients.filter(c => c.email.toLowerCase().includes(q))
          .sort((a, b) => a.email.localeCompare(b.email));
      },
      availableAccessProducts() {
        const granted = new Set(this.grants.map(g => Number(g.product_id)));
        const q = this.accessProductQuery.trim().toLowerCase();
        return this.products.filter(p => !p.deleted_at && !granted.has(p.id) &&
          [p.name, p.currency, p.face_value].some(value => String(value).toLowerCase().includes(q)));
      },
      matchingAccessGrants() {
        const q = this.accessGrantQuery.trim().toLowerCase();
        return this.grants.filter(g => [g.product_name, g.brand_name, g.product_currency]
          .some(value => String(value || "").toLowerCase().includes(q)));
      }
    },
    mounted() {
      // Use the page scroll, not scrollable tables or modal bodies.
      window.addEventListener("scroll", this.updateBackToTop, { passive: true });
      this.updateBackToTop();
    },
    beforeUnmount() {
      window.removeEventListener("scroll", this.updateBackToTop);
    },
    methods: {
      updateBackToTop() {
        this.showBackToTop = window.scrollY > 360;
      },
      scrollToTop() {
        if (this.cardModalOpen || this.reportDrilldownOpen || this.errorModalOpen || this.directoryModalKind) return;
        window.scrollTo({
          top: 0,
          behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth"
        });
      },
      async scrollToSaveNotice(result) {
        // Create returns false and Update returns true; only null means failure.
        if (result === null) return;
        await this.$nextTick();
        this.scrollToTop();
      },
      listVisiblePages(page, count) {
        const first = Math.max(1, Math.min(page - 2, count - 4));
        return Array.from({ length: Math.min(5, count) }, (_, i) => first + i);
      },
      async scrollToDirectoryList(kind) {
        await this.$nextTick();
        this.$refs[kind + "ListTop"]?.scrollIntoView({
          behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
          block: "start"
        });
      },
      async changeDirectoryPage(kind, next) {
        const fields = { brands: ["brandPage", "brandPageCount", "fetchBrands"],
          clients: ["clientPage", "clientPageCount", "fetchClients"],
          audit: ["auditPage", "auditPageCount", "fetchAudit"] }[kind];
        if (!fields || this.busy || this.tab !== kind || !Number.isSafeInteger(next) ||
            next < 1 || next > this[fields[1]] || next === this[fields[0]]) return;
        const previous = this[fields[0]];
        this[fields[0]] = next;
        const result = await this.execute(() => this[fields[2]](), null, "table");
        if (!result) { this[fields[0]] = previous; return; }
        await this.scrollToDirectoryList(kind);
      },
      async changeDirectoryPerPage(kind) {
        const fields = { brands: ["brandPage", "fetchBrands"],
          clients: ["clientPage", "fetchClients"], audit: ["auditPage", "fetchAudit"] }[kind];
        if (!fields || this.busy || this.tab !== kind) return;
        this[fields[0]] = 1;
        await this.execute(() => this[fields[1]](), null, "table");
      },
      async openDirectoryModal(kind, record) {
        if (!["brands", "clients", "products", "audit"].includes(kind) || !record) return;
        this.directoryModalTrigger = document.activeElement;
        this.directoryModalPreviousOverflow = document.body.style.overflow;
        document.body.style.overflow = "hidden";
        this.directoryModalKind = kind;
        this.directoryModalRecord = record;
        await this.$nextTick();
        this.$refs.directoryModalHeading?.focus({ preventScroll: true });
      },
      closeDirectoryModal(restoreFocus = true) {
        if (!this.directoryModalKind) return;
        this.directoryModalKind = null;
        this.directoryModalRecord = null;
        document.body.style.overflow = this.directoryModalPreviousOverflow;
        const trigger = this.directoryModalTrigger;
        this.directoryModalTrigger = null;
        this.directoryModalPreviousOverflow = "";
        if (restoreFocus) this.$nextTick(() => {
          const target = trigger?.isConnected ? trigger : document.querySelector(".nav-link.selected");
          target?.focus({ preventScroll: true });
        });
      },
      trapDirectoryModalFocus(event) {
        const box = this.$refs.directoryModalDialog;
        if (!box) return;
        const elements = [...box.querySelectorAll('button:not([disabled]),a[href]')]
          .filter(el => el.getClientRects().length);
        if (!elements.length) return;
        if (event.shiftKey && (document.activeElement === elements[0] ||
            document.activeElement === this.$refs.directoryModalHeading)) {
          event.preventDefault(); elements[elements.length - 1].focus();
        } else if (!event.shiftKey && document.activeElement === elements[elements.length - 1]) {
          event.preventDefault(); elements[0].focus();
        }
      },
      safeAuditFields(data) {
        if (data == null) return {};
        if (Array.isArray(data)) return data.map(value => this.safeAuditFields(value));
        if (typeof data !== "object") return data;
        return Object.fromEntries(Object.entries(data).map(([key, value]) => [
          key, /password|pin|secret|token|credential|authorization|digest|cipher|fingerprint|api.key/i.test(key)
            ? "[REDACTED]" : this.safeAuditFields(value)
        ]));
      },
      cardSortAria(column) {
        return this.cardSortBy === column
          ? (this.cardSortDir === "asc" ? "ascending" : "descending") : "none";
      },
      cardSortIcon(column) {
        return this.cardSortBy === column ? (this.cardSortDir === "asc" ? "↑" : "↓") : "↕";
      },
      cardSortLabel(column, label) {
        const direction = this.cardSortBy === column && this.cardSortDir === "asc"
          ? "descending" : "ascending";
        return "Sort by " + label + " " + direction;
      },
      pretty(data) { return data == null ? "{}" : JSON.stringify(data, null, 2); },
      brandName(id) { return this.brands.find(b => b.id === Number(id))?.name || ("Brand #" + id); },
      clientName(id) { return this.clients.find(c => c.id === Number(id))?.email || ("Client #" + id); },
      money(value, currency) { return value + " " + currency; },
      entityHref(kind, id) {
        return "#/" + encodeURIComponent(kind) + "/" + encodeURIComponent(id);
      },
      canOpenAuditActor(event) {
        return event.actor_id && this.clients.some(c => c.id === Number(event.actor_id));
      },
      auditEntity(event) {
        if (!event.record_id) return null;
        if (event.record_type === "Brand") return { kind: "brands", id: event.record_id };
        if (event.record_type === "Product") return { kind: "products", id: event.record_id };
        if (event.record_type === "User" &&
          this.clients.some(c => c.id === Number(event.record_id)))
          return { kind: "clients", id: event.record_id };
        if (event.record_type === "ProductAccess") {
          const attributes = event.after_data || event.before_data || {};
          if (attributes.client_id) return { kind: "grants", id: attributes.client_id };
        }
        return null; // Admin has no card detail endpoint; do not render a broken link.
      },
      async navigateTo(kind, rawId) {
        if (this.busy || !this.session) return;
        const id = Number(rawId);
        if (!Number.isSafeInteger(id) || id <= 0) return;
        const admin = this.session.user.role === "admin";
        if (kind === "catalog-brand" && !admin) {
          // An explicit Brand link is an intentional, one-time Catalog filter.
          await this.go("catalog", { brandId: id });
        } else if (kind === "issue-product" && !admin) {
          // Transfer just the selected Product ID. Catalog filters never travel.
          await this.go("issue", { selectedProductId: id });
        } else if (kind === "cards" && !admin) {
          // A cross-page link opens the normal, unfiltered My cards list first.
          // The target detail is independent of the first 100 visible rows.
          await this.go("cards");
          if (!this.session || this.tab !== "cards" || this.lastApiError) return;
          let card = this.cards.find(item => item.id === id);
          if (!card) {
            const result = await this.execute(
              () => this.request("GET", apiRoot + "client/cards/" + id), null, "detail");
            if (!result) return;
            card = result.payload.data;
          }
          this.cardDetail = card;
          await this.openCardDetails();
        } else if (admin && kind === "brands-products") {
          this.brandId = id;
          await this.go("products");
        } else if (admin && kind === "grants") {
          this.clientId = id;
          this.accessClientQuery = "";
          this.accessPickerOpen = false;
          await this.go("grants", { preserveGrantClient: true });
        } else if (admin && ["brands", "clients"].includes(kind)) {
          if (this.tab !== kind) await this.go(kind);
          if (this.tab === kind) await this.inspect(kind, id);
        } else if (admin && kind === "products") {
          if (this.tab === "products") {
            // The row may be on another page: inspect fetches only the show
            // endpoint when needed, without disturbing catalog pagination.
            await this.inspect(kind, id);
          } else {
            // Audit/Product access -> Product: show the exact target and keep a
            // clearly labelled preview, never pretend it is a full Brand list.
            let record = this.products.find(item => item.id === id);
            if (!record) {
              const result = await this.execute(
                () => this.request("GET", apiRoot + "admin/products/" + id), null, "detail");
              if (!result) return;
              record = result.payload.data;
            }
            this.brandId = record.brand_id;
            this.products = [record];
            this.productCatalogPreview = true;
            this.productPage = 1;
            this.productTotal = 1;
            this.tab = kind;
            this.selectedDetail = { kind, data: record };
            this.cardDetail = null;
            await this.openDirectoryModal(kind, record);
          }
        }
      },
      reportValue(row, key) {
        if (key === "brand_id") return this.brandName(row[key]);
        if (key === "client_id") return this.clientName(row[key]);
        return row[key] ?? "—";
      },
      reportGroupLabel(row) {
        if (this.session?.user.role === "client")
          return row.brand_name || ("Brand #" + row.brand_id);
        if (this.reportGroup === "by_brand")
          return row.brand_name || this.brandName(row.brand_id);
        return row.client_email || this.clientName(row.client_id);
      },
      reportInteger(value) { return Number(value || 0).toLocaleString("en-US"); },
      reportCents(value) {
        const match = String(value ?? "0").match(/^(-?)(\d+)(?:\.(\d{1,}))?$/);
        if (!match) return 0n;
        const cents = BigInt(match[2]) * 100n +
          BigInt((match[3] || "").padEnd(2, "0").slice(0, 2));
        return match[1] ? -cents : cents;
      },
      reportFormattedCents(cents, currency) {
        const sign = cents < 0n ? "-" : "";
        const positive = cents < 0n ? -cents : cents;
        return sign + (positive / 100n).toLocaleString("en-US") +
          "." + String(positive % 100n).padStart(2, "0") + " " + currency;
      },
      reportMoney(value, currency) {
        return this.reportFormattedCents(this.reportCents(value), currency);
      },
      reportUtcDate(date) { return date.toISOString().slice(0, 10); },
      async chooseReportPreset(preset) {
        if (this.busy || !["all", "month", "last30"].includes(preset)) return;
        const now = new Date();
        const year = now.getUTCFullYear(), month = now.getUTCMonth();
        const midnight = Date.UTC(year, month, now.getUTCDate());
        if (preset === "all") {
          this.reportFrom = "";
          this.reportTo = "";
        } else if (preset === "month") {
          this.reportFrom = this.reportUtcDate(new Date(Date.UTC(year, month, 1)));
          this.reportTo = this.reportUtcDate(new Date(Date.UTC(year, month + 1, 1)));
        } else {
          this.reportFrom = this.reportUtcDate(new Date(midnight - 29 * 86400000));
          this.reportTo = this.reportUtcDate(new Date(midnight + 86400000));
        }
        this.reportPreset = preset;
        await this.loadReport();
      },
      auditRecordLabel(event) {
        if (event.record_label) return event.record_label;
        const data = event.after_data || event.before_data || {};
        if (["Brand", "Product"].includes(event.record_type))
          return (data.name || event.record_type) + " (" + event.record_type + ")";
        if (event.record_type === "User") return data.email || event.actor_email || "Client account";
        if (event.record_type === "ProductAccess")
          return "Product access · " + this.clientName(data.client_id);
        if (event.record_type === "Card") return "Gift card · " + (data.status || "transaction");
        return event.record_type || "System event";
      },
      parseFields(raw) {
        let value;
        try { value = JSON.parse(raw || "{}"); }
        catch { throw new Error("Custom fields must contain valid JSON."); }
        if (!value || Array.isArray(value) || typeof value !== "object" || Object.keys(value).length > 5)
          throw new Error("Custom fields must be a JSON object with at most five keys.");
        return value;
      },
      async scrollToEditForm(kind) {
        await this.$nextTick();
        if (this.tab !== kind) return;
        this.$refs[kind + "EditForm"]?.scrollIntoView({
          behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
          block: "start"
        });
      },
      resetBrand() {
        this.editingBrandId = null;
        this.brandForm = { name: "", state: "active", custom_fields: "{}" };
      },
      resetProduct() {
        this.editingProductId = null;
        this.productForm = { brand_id: this.brandId || "", name: "", face_value: "100.00",
          currency: "USD", state: "active", custom_fields: "{}" };
      },
      resetClient() {
        this.editingClientId = null;
        this.clientForm = { email: "", password: "", payout_rate: "90", active: true };
      },
      editBrand(record) {
        this.editingBrandId = record.id;
        this.brandForm = { name: record.name, state: record.state,
          custom_fields: this.pretty(record.custom_fields || {}) };
        this.scrollToEditForm("brands");
      },
      editProduct(record) {
        this.editingProductId = record.id;
        this.productForm = { brand_id: record.brand_id, name: record.name,
          face_value: record.face_value, currency: record.currency, state: record.state,
          custom_fields: this.pretty(record.custom_fields || {}) };
        this.scrollToEditForm("products");
      },
      editClient(record) {
        this.editingClientId = record.id;
        this.clientForm = { email: record.email, password: "",
          payout_rate: record.payout_rate, active: record.active };
        this.scrollToEditForm("clients");
      },
      async inspect(kind, id) {
        if (this.busy) return;
        if (kind === "cards") this.hideCardPin();
        const routes = { brands: "admin/brands/", products: "admin/products/",
          clients: "admin/clients/", cards: "client/cards/" };
        if (!routes[kind]) return;
        const collections = { brands: this.brands, products: this.products,
          clients: this.clients, cards: this.cards };
        const existing = collections[kind].find(record => record.id === Number(id));
        if (existing) {
          if (kind === "cards") {
            this.cardDetail = existing;
            await this.openCardDetails();
          } else {
            this.selectedDetail = { kind, data: existing };
            if (kind === "brands" || kind === "clients" || kind === "products")
              await this.openDirectoryModal(kind, existing);
          }
          return;
        }
        // A deep-linked or paginated-out record is the only case needing GET show.
        const result = await this.execute(async () => {
          const res = await this.request("GET", apiRoot + routes[kind] + encodeURIComponent(id));
          if (kind === "cards") this.cardDetail = res.payload.data;
          else this.selectedDetail = { kind, data: res.payload.data };
          return res;
        }, null, "detail");
        if (kind === "cards" && result) await this.openCardDetails();
        if (["brands", "clients", "products"].includes(kind) && result)
          await this.openDirectoryModal(kind, result.payload.data);
      },
      hideIssuedPin() {
        if (this.issuedPinTimer) window.clearTimeout(this.issuedPinTimer);
        this.issuedPinTimer = null;
        this.issuedPinVisible = false;
      },
      forgetIssuedPin() {
        this.hideIssuedPin();
        // Once leaving the issuance workspace, discard its plaintext PIN.
        // It can be recovered via the password-confirmed My cards workflow.
        if (this.issued?.pin) this.issued = { ...this.issued, pin: null };
      },
      showIssuedPin() {
        if (!this.issued?.pin) return;
        this.hideIssuedPin();
        this.issuedPinVisible = true;
        this.issuedPinTimer = window.setTimeout(() => this.hideIssuedPin(), 30000);
      },
      hideCardPin() {
        if (this.revealedCardPinTimer) window.clearTimeout(this.revealedCardPinTimer);
        this.revealedCardPinTimer = null;
        this.revealedCardPin = "";
        this.pinRevealError = "";
        if (this.$refs.pinPasswordInput) this.$refs.pinPasswordInput.value = "";
      },
      async revealCardPin() {
        const selected = this.cardDetail;
        const input = this.$refs.pinPasswordInput;
        const password = input?.value || "";
        if (!selected?.has_pin || !password) {
          this.pinRevealError = "Enter your account password to reveal this Card's PIN.";
          input?.focus();
          return;
        }
        this.hideCardPin();
        try {
          await this.execute(async () => {
            const res = await this.request("POST", apiRoot + "client/cards/" +
              encodeURIComponent(selected.id) + "/reveal_pin", { password });
            if (this.cardModalOpen && this.cardDetail?.id === selected.id) {
              this.revealedCardPin = res.payload.data.pin;
              this.revealedCardPinTimer = window.setTimeout(() => this.hideCardPin(), 30000);
            }
            return res;
          }, "PIN displayed for up to 30 seconds.", "submit", true);
        } finally {
          if (input) input.value = "";
        }
      },
      async openCardDetails() {
        if (!this.cardDetail) return;
        // Leave the list position untouched; only the dialog content can scroll.
        if (!this.cardModalOpen) {
          this.cardModalTrigger = document.activeElement;
          this.cardModalPreviousOverflow = document.body.style.overflow;
          document.body.style.overflow = "hidden";
        }
        this.cardModalOpen = true;
        await this.$nextTick();
        this.$refs.cardDetailsHeading?.focus({ preventScroll: true });
      },
      closeCardDetails(restoreFocus = true) {
        if (!this.cardModalOpen) return;
        this.hideCardPin(); // Clear plaintext PIN, its timer, password, and errors.
        this.cardModalOpen = false;
        this.cardDetail = null;
        document.body.style.overflow = this.cardModalPreviousOverflow;
        const trigger = this.cardModalTrigger;
        this.cardModalTrigger = null;
        this.cardModalPreviousOverflow = "";
        if (restoreFocus) this.$nextTick(() => {
          const target = trigger?.isConnected && trigger.matches?.("a,button,input,select,textarea,[tabindex]")
            ? trigger : document.querySelector(".nav-link.selected");
          target?.focus({ preventScroll: true });
        });
      },
      trapCardModalFocus(event) {
        if (!this.cardModalOpen) return;
        const modal = this.$refs.cardDetailDialog;
        if (!modal) return;
        const focusable = [...modal.querySelectorAll(
          'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'
        )].filter(el => el.getClientRects().length);
        if (!focusable.length) return;
        const first = focusable[0], last = focusable[focusable.length - 1];
        if (event.shiftKey && (document.activeElement === first ||
            document.activeElement === this.$refs.cardDetailsHeading)) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      },
      notify(message, kind = "success") {
        this.flash = { text: message, kind };
      },
      validationDetails(error) {
        // Exception diagnostics may also have a `details` object. Only model
        // validation failures may be interpreted as per-field form errors.
        if (error?.body?.error?.code !== "validation_failed") return [];
        const details = error?.body?.error?.details;
        if (!details || typeof details !== "object" || Array.isArray(details)) return [];
        const labels = {
          email: "Email address", password: "Password", payout_rate: "Payout rate",
          name: "Name", face_value: "Face value", currency: "Currency",
          state: "Status", custom_fields: "Custom fields", product_id: "Product"
        };
        return Object.entries(details).flatMap(([field, errors]) => {
          const values = Array.isArray(errors) ? errors : [errors];
          return values.filter(message => typeof message === "string" && message.trim())
            .map(message => {
              if (field === "email" && message.trim() === "has already been taken") {
                return { field, message: "Email address is already in use. Please enter a different email address." };
              }
              const label = labels[field] || field.replaceAll("_", " ");
              const normalized = message.trim().replace(/\.$/, "");
              return { field, message: label + " " + normalized + "." };
            });
        });
      },
      fieldError(field) {
        return this.validationErrors.find(item => item.field === field)?.message || "";
      },
      clearFieldError(field) {
        this.validationErrors = this.validationErrors.filter(item => item.field !== field);
        if (!this.validationErrors.length && this.flash.kind === "error" &&
          this.flash.text === "Please correct the following fields:") this.flash.text = "";
      },
      errorMessage(error) {
        const status = Number(error?.status || 0);
        const code = error?.body?.error?.code;
        if (code === "route_not_found")
          return "That API endpoint doesn't exist. Check the URL and try again.";
        if (status >= 500)
          return "The server couldn't complete this request. Please try again or contact support.";
        if (status === 404)
          return "The requested item or API endpoint couldn't be found.";
        if (status === 403 && code === "forbidden")
          return "Your account doesn't have permission to perform this action.";
        if (status === 401)
          return "Your session is no longer valid. Please sign in again.";
        const message = error?.body?.error?.message;
        return typeof message === "string" && message.length <= 250
          ? message : (error?.message || "The request could not be completed.");
      },
      safeRawError(value) {
        // The modal displays the HTTP response (not the server log). Redact secret
        // keys even if a backend regression accidentally puts them in an error.
        const seen = new WeakSet();
        const sanitize = (item, key = "") => {
          if (/(password|pin|token|authorization|secret|credential|activation_number|idempotency_key)/i.test(key))
            return "[REDACTED]";
          if (typeof item === "string") return item
            .replace(/Bearer\s+[A-Za-z0-9._-]+/gi, "Bearer [REDACTED]")
            .replace(/((?:password|pin|token|secret|authorization)\s*[=:]\s*)[^\s&"']+/gi, "$1[REDACTED]");
          if (!item || typeof item !== "object") return item;
          if (seen.has(item)) return "[CIRCULAR]";
          seen.add(item);
          if (Array.isArray(item)) return item.slice(0, 70).map(entry => sanitize(entry));
          return Object.fromEntries(Object.entries(item).slice(0, 70)
            .map(([name, entry]) => [name, sanitize(entry, name)]));
        };
        return JSON.stringify(sanitize(value), null, 2).slice(0, 20000);
      },
      rememberApiError(error, method, path) {
        const status = error?.status || null;
        const payload = error?.body || { error: { message: error?.message || "Request failed" } };
        this.lastApiError = {
          status, method: method || error?.method || "Request",
          path: (path || error?.path || "").split("?")[0],
          requestId: payload?.request_id || null,
          message: this.errorMessage(error),
          raw: this.safeRawError(payload)
        };
      },
      async openErrorDetails() {
        if (!this.lastApiError) return;
        this.errorModalOpen = true;
        await this.$nextTick();
        this.$refs.errorModalClose?.focus();
      },
      closeErrorDetails() {
        this.errorModalOpen = false;
        this.$nextTick(() => this.$refs.errorDetailsTrigger?.focus());
      },
      async request(method, path, body, key, accessToken) {
        // Always use root-relative API paths; disallow external origins and protocol-relative URLs.
        if (typeof path !== "string" || !path.startsWith(apiRoot) || path.includes("//") || /[\r\n\\#]/.test(path)) {
          throw new Error("Only same-origin /api/v1/ paths are allowed.");
        }
        const url = new URL(path, window.location.origin);
        if (url.origin !== window.location.origin || !url.pathname.startsWith(apiRoot)) {
          throw new Error("External URLs are not allowed.");
        }
        const headers = { Accept: "application/json" };
        const token = accessToken === undefined ? this.session?.token : accessToken;
        if (token) headers.Authorization = "Bearer " + token;
        if (key) headers["Idempotency-Key"] = key;
        const options = { method, headers, cache: "no-store", credentials: "same-origin" };
        if (body !== undefined && body !== null && method !== "GET") {
          headers["Content-Type"] = "application/json";
          options.body = JSON.stringify(body);
        }
        const started = performance.now();
        const res = await fetch(url.pathname + url.search, options);
        const duration = Math.round(performance.now() - started);
        const raw = await res.text();
        let payload;
        try { payload = raw ? JSON.parse(raw) : null; }
        catch { payload = { raw: raw.slice(0, 4000) }; }
        if (!res.ok) {
          const err = new Error(payload?.error?.message || "HTTP " + res.status);
          err.status = res.status;
          err.body = payload;
          err.duration = duration;
          err.method = method;
          err.path = url.pathname;
          throw err;
        }
        return { status: res.status, payload, duration };
      },
      async execute(fn, success, mode = "submit", inlinePinError = false) {
        if (this.busy) return null;
        this.busy = true;
        this.loadingTable = mode === "table";
        this.loadingDetail = mode === "detail";
        this.submitting = mode === "submit";
        this.flash.text = "";
        this.validationErrors = [];
        this.lastApiError = null;
        this.errorModalOpen = false;
        try {
          const result = await fn();
          if (success) this.notify(typeof success === "function" ? success(result) : success);
          return result;
        } catch (error) {
          this.rememberApiError(error);
          if (error.status === 401 && this.session) {
            this.clearSession();
            this.notify("Session expired or account disabled. Sign in again.", "error");
          } else if (inlinePinError) {
            // Reveal PIN failures belong beside the password field, not in the page header.
            this.pinRevealError = this.errorMessage(error);
          } else {
            this.validationErrors = this.validationDetails(error);
            this.notify(this.validationErrors.length
              ? "Please correct the following fields:"
              : this.errorMessage(error), "error");
          }
          return null;
        } finally {
          this.busy = false;
          this.loadingTable = false;
          this.loadingDetail = false;
          this.submitting = false;
        }
      },
      clearSession() {
        this.closeDirectoryModal(false);
        this.closeReportDrilldown(false);
        this.closeCardDetails(false);
        this.hideCardPin();
        this.hideIssuedPin();
        this.validationErrors = [];
        this.session = null;
        this.loadingTable = false;
        this.loadingDetail = false;
        this.submitting = false;
        this.issued = null;
        this.issuedHttpStatus = null;
        this.issueProductQuery = "";
        this.issueForm = { product_id: "", key: "", with_pin: false };
        this.catalogQuery = "";
        this.catalogCurrency = "";
        this.catalogBrandId = "";
        this.selectedDetail = null;
        this.cardDetail = null;
        this.editingBrandId = this.editingProductId = this.editingClientId = null;
        this.brands = []; this.products = []; this.clients = []; this.grants = [];
        this.clientId = ""; this.accessClientQuery = ""; this.accessPickerOpen = false;
        this.accessProductQuery = ""; this.accessGrantQuery = "";
        this.catalog = []; this.issueCatalog = []; this.cards = []; this.audits = [];
        this.cardStatus = ""; this.cardPinFilter = ""; this.cardQuery = "";
        this.cardPage = 1; this.cardPerPage = 25; this.cardTotal = 0;
        this.cardSortBy = ""; this.cardSortDir = "asc";
        this.productPage = 1; this.productPerPage = 25; this.productTotal = 0;
        this.productCatalogPreview = false;
        this.brandPage = 1; this.brandPerPage = 25; this.brandTotal = 0;
        this.clientPage = 1; this.clientPerPage = 25; this.clientTotal = 0;
        this.auditPage = 1; this.auditPerPage = 25; this.auditTotal = 0; this.auditAppliedFilters = {};
        this.loginForm.email = "";
        this.loginForm.password = "";
        this.consoleForm = { method: "GET", path: "/api/v1/client/catalog", body: "", key: "" };
        this.consoleTemplateId = "";
        this.auditAction = ""; this.auditActor = ""; this.auditOutcome = "";
        this.auditFrom = ""; this.auditTo = "";
        this.response = { method: "", path: "", body: null, status: null, duration: "—" };
        this.tab = "overview";
      },
      async login() {
        await this.execute(async () => {
          const result = await this.request("POST", apiRoot + "auth/login",
            { email: this.loginForm.email, password: this.loginForm.password });
          const data = result.payload.data;
          if (!data?.access_token || !["admin", "client"].includes(data.user?.role)) {
            throw new Error("Unexpected sign-in response.");
          }
          this.session = { token: data.access_token, user: data.user,
            email: this.loginForm.email.toLowerCase() };
          this.loginForm.password = "";
          this.tab = "overview";
          return result;
        }, () => "Signed in successfully.");
      },
      async logout() {
        if (!this.session) return;
        // Logout records an audit event; JWT revocation is not implemented server-side.
        this.busy = true;
        this.submitting = true;
        try { await this.request("POST", apiRoot + "auth/logout"); }
        catch { /* Discard local token even when the server is unavailable. */ }
        finally {
          this.clearSession();
          this.busy = false;
          this.notify("Signed out. Your in-memory token has been discarded.");
        }
      },
      async go(section, { preserveGrantClient = false, brandId = null, selectedProductId = null } = {}) {
        if (this.busy || !this.menu.some(item => item.id === section)) return;
        this.closeDirectoryModal(false);
        this.closeReportDrilldown(false);
        this.closeCardDetails(false);
        this.hideCardPin();
        if (section !== "issue") this.forgetIssuedPin();
        if (section === "catalog") {
          // A new Catalog visit must never inherit old searches/currency/Brand.
          // The Brand link is the only explicit navigation filter.
          this.catalogQuery = "";
          this.catalogCurrency = "";
          this.catalogBrandId = brandId || "";
        }
        if (section === "issue") {
          // Sidebar opens a clean chooser; Catalog product links supply only an ID.
          this.issueProductQuery = "";
          this.issueForm.product_id = selectedProductId || "";
        }
        if (this.tab !== section) {
          if (section === "brands") this.brandPage = 1;
          if (section === "clients") this.clientPage = 1;
          if (section === "audit") this.auditPage = 1;
        }
        if (section === "products" && this.tab !== section) {
          // A new Products visit starts on the first page of the chosen Brand.
          this.productPage = 1;
          this.productTotal = 0;
          this.productCatalogPreview = false;
        }
        if (section === "cards") {
          // Each My cards visit starts unfiltered, even when opened via a Card link.
          this.cardQuery = "";
          this.cardStatus = "";
          this.cardPinFilter = "";
          this.cardPage = 1;
          this.cardTotal = 0;
          this.cardSortBy = "";
          this.cardSortDir = "asc";
          this.cards = [];
        }
        // Navigation from a Client or Audit link retains the targeted Client;
        // a direct menu visit asks for an explicit Client selection.
        if (section === "grants" && !preserveGrantClient && this.tab !== section) {
          this.clientId = "";
          this.accessClientQuery = "";
        }
        if (section === "console" && this.tab !== section) {
          // Re-entering Console uses a safe read-only example for the current role.
          this.applyConsoleTemplate(this.session.user.role === "admin" ? "admin-brands" : "client-catalog");
        }
        if (section === "grants") this.accessPickerOpen = false;
        this.validationErrors = [];
        this.tab = section;
        this.selectedDetail = null;
        this.cardDetail = null;
        await this.refresh();
      },
      async refresh() {
        const role = this.session?.user?.role;
        if (!role || this.tab === "overview" || this.tab === "console") return;
        await this.execute(async () => {
          if (role === "admin") {
            if (["brands", "products", "grants", "reports"].includes(this.tab)) await this.fetchBrands();
            if (["clients", "grants", "reports", "audit"].includes(this.tab)) await this.fetchClients();
            if (["products", "grants"].includes(this.tab)) await this.fetchProducts();
            if (this.tab === "grants") await this.fetchGrants();
            if (this.tab === "reports") await this.fetchReport();
            if (this.tab === "audit") await this.fetchAudit();
          } else {
            if (this.tab === "catalog") await this.fetchCatalog();
            if (this.tab === "issue") await this.fetchIssueCatalog();
            if (this.tab === "cards") await this.fetchCards();
            if (this.tab === "reports") await this.fetchReport();
          }
          // An explicit Refresh is authoritative: update/clear any visible cached detail.
          const lists = { brands: this.brands, products: this.products,
            clients: this.clients, cards: this.cards };
          if (this.selectedDetail?.kind === this.tab && lists[this.tab]) {
            const record = lists[this.tab].find(item => item.id === this.selectedDetail.data.id);
            this.selectedDetail = record ? { kind: this.tab, data: record } : null;
          }
          if (this.tab === "cards" && this.cardDetail) {
            this.cardDetail = this.cards.find(item => item.id === this.cardDetail.id) || null;
          }
        }, null, "table");
      },
      async fetchFullAdminDirectory(resource) {
        // Related Admin selectors are loaded fully, independently of pagination.
        const root = apiRoot + "admin/" + resource;
        const params = new URLSearchParams({ page: "1", per_page: "100" });
        const first = await this.request("GET", root + "?" + params);
        const records = [...(first.payload.data || [])];
        const total = Number(first.payload.meta?.total) || records.length;
        for (let page = 2; records.length < total; page++) {
          params.set("page", String(page));
          const response = await this.request("GET", root + "?" + params);
          const next = response.payload.data || [];
          if (!next.length) break;
          records.push(...next);
        }
        return { data: records, meta: { total } };
      },
      async fetchBrands() {
        const directory = this.tab === "brands";
        const page = directory ? this.brandPage : 1;
        const perPage = directory ? this.brandPerPage : 100;
        const res = directory
          ? await this.request("GET", apiRoot + "admin/brands?page=" + page + "&per_page=" + perPage)
          : { payload: await this.fetchFullAdminDirectory("brands") };
        const total = Number(res.payload.meta?.total) || 0;
        if (directory && page > 1 && page > Math.max(1, Math.ceil(total / perPage))) {
          this.brandPage = Math.max(1, Math.ceil(total / perPage));
          return this.fetchBrands();
        }
        this.brands = res.payload.data || [];
        if (directory) this.brandTotal = total;
        if (!directory && !this.brands.some(b => b.id === Number(this.brandId))) this.brandId = this.brands[0]?.id || "";
        if (!this.editingProductId && !this.brands.some(b => b.id === Number(this.productForm.brand_id)))
          this.productForm.brand_id = this.brands[0]?.id || "";
        return res;
      },
      async fetchProducts() {
        if (!this.brandId) {
          this.products = [];
          if (this.tab === "products") this.productTotal = 0;
          return;
        }
        // Product Access keeps its existing independent 100-record loader.
        // Only Brand Catalog uses this dedicated server-side pagination state.
        const catalog = this.tab === "products";
        const perPage = catalog ? this.productPerPage : 100;
        const page = catalog ? this.productPage : 1;
        const q = new URLSearchParams({ page: String(page), per_page: String(perPage) });
        const url = apiRoot + "admin/brands/" + encodeURIComponent(this.brandId) + "/products?" + q;
        const res = await this.request("GET", url);
        const total = Number(res.payload.meta?.total) || 0;
        if (catalog && page > 1 && page > Math.max(1, Math.ceil(total / perPage))) {
          // Concurrent Product changes can shrink the last page.
          this.productPage = Math.max(1, Math.ceil(total / perPage));
          return this.fetchProducts();
        }
        this.products = res.payload.data || [];
        if (catalog) {
          this.productTotal = total;
          this.productCatalogPreview = false;
        }
        return res;
      },
      async fetchClients() {
        const directory = this.tab === "clients";
        const page = directory ? this.clientPage : 1;
        const perPage = directory ? this.clientPerPage : 100;
        const res = directory
          ? await this.request("GET", apiRoot + "admin/clients?page=" + page + "&per_page=" + perPage)
          : { payload: await this.fetchFullAdminDirectory("clients") };
        const total = Number(res.payload.meta?.total) || 0;
        if (directory && page > 1 && page > Math.max(1, Math.ceil(total / perPage))) {
          this.clientPage = Math.max(1, Math.ceil(total / perPage));
          return this.fetchClients();
        }
        this.clients = res.payload.data || [];
        if (directory) this.clientTotal = total;
        if (!directory && !this.clients.some(c => c.id === Number(this.clientId)))
          this.clientId = this.tab === "grants" ? "" : (this.clients[0]?.id || "");
        return res;
      },
      async fetchGrants() {
        this.grants = [];
        if (!this.clientId) return;
        const res = await this.request("GET", apiRoot + "admin/clients/" + encodeURIComponent(this.clientId) + "/product_accesses?per_page=100");
        this.grants = res.payload.data || [];
      },
      async fetchCatalog() {
        const params = new URLSearchParams();
        if (this.catalogQuery.trim()) params.set("q", this.catalogQuery.trim());
        if (this.catalogCurrency.trim()) params.set("currency", this.catalogCurrency.trim().toUpperCase());
        if (this.catalogBrandId) params.set("brand_id", String(this.catalogBrandId));
        const res = await this.request("GET", apiRoot + "client/catalog" + (params.size ? "?" + params : ""));
        this.catalog = res.payload.data || [];
      },
      async fetchIssueCatalog() {
        // Issue card always has the full eligible set, independently of Catalog.
        const res = await this.request("GET", apiRoot + "client/catalog");
        this.issueCatalog = res.payload.data || [];
        // Clear a stale one-time selection if permission was revoked meanwhile.
        if (!this.issueCatalog.some(p => p.id === Number(this.issueForm.product_id)))
          this.issueForm.product_id = "";
      },
      async fetchCards() {
        this.hideCardPin();
        const q = new URLSearchParams({
          page: String(this.cardPage), per_page: String(this.cardPerPage)
        });
        if (this.cardQuery.trim()) q.set("q", this.cardQuery.trim());
        if (this.cardStatus) q.set("status", this.cardStatus);
        if (this.cardPinFilter) q.set("has_pin", this.cardPinFilter === "with" ? "true" : "false");
        if (this.cardSortBy) {
          q.set("sort_by", this.cardSortBy);
          q.set("sort_dir", this.cardSortDir);
        }
        const res = await this.request("GET", apiRoot + "client/cards?" + q);
        this.cards = res.payload.data || [];
        this.cardTotal = Number(res.payload.meta?.total) || 0;
        // A cancellation or concurrent change can shrink the result set.
        // Recover the last populated page rather than trapping the user on an empty page.
        if (this.cardPage > this.cardPageCount) {
          this.cardPage = this.cardPageCount;
          return this.fetchCards();
        }
        if (this.cardDetail && !this.cards.some(c => c.id === this.cardDetail.id)) {
          if (this.cardModalOpen) this.closeCardDetails(false);
          else this.cardDetail = null;
        }
        return res;
      },
      async openReportCards(row, event) {
        if (this.busy || !this.session || this.tab !== "reports" ||
            !["issued", "cancelled"].includes(event) || Number(row[event + "_count"]) <= 0) return;
        const isAdmin = this.session.user.role === "admin";
        const grouped = isAdmin ? this.reportGroup === "by_brand" : this.reportClientGroup === "brand";
        this.reportDrilldownSelection = {
          currency: row.currency, event, expected: Number(row[event + "_count"]),
          from: this.reportAppliedFrom, to: this.reportAppliedTo,
          groupBy: isAdmin ? (grouped ? "brand" : "client") : (grouped ? "brand" : "currency"),
          groupId: grouped ? row.brand_id : (isAdmin ? row.client_id : null),
          groupLabel: grouped || isAdmin ? this.reportGroupLabel(row) : "My cards"
        };
        this.reportDrilldownTrigger = document.activeElement;
        this.reportDrilldownOverflow = document.body.style.overflow;
        document.body.style.overflow = "hidden";
        this.reportDrilldownRows = [];
        this.reportDrilldownTotal = 0;
        this.reportDrilldownPage = 1;
        this.reportDrilldownOpen = true;
        await this.$nextTick();
        this.$refs.reportDrilldownHeading?.focus({ preventScroll: true });
        await this.loadReportDrilldown();
      },
      async loadReportDrilldown() {
        const selection = this.reportDrilldownSelection;
        if (!selection || !this.reportDrilldownOpen) return false;
        const result = await this.execute(() => {
          const q = new URLSearchParams({
            currency: selection.currency, event: selection.event,
            page: String(this.reportDrilldownPage),
            per_page: String(this.reportDrilldownPerPage)
          });
          if (selection.from) q.set("from", selection.from);
          if (selection.to) q.set("to", selection.to);
          const isAdmin = this.session.user.role === "admin";
          if (isAdmin) {
            q.set("group_by", selection.groupBy);
            q.set(selection.groupBy === "brand" ? "brand_id" : "client_id", String(selection.groupId));
          } else if (selection.groupBy === "brand") {
            q.set("brand_id", String(selection.groupId));
          }
          return this.request("GET", apiRoot + (isAdmin ? "admin" : "client") +
            "/reports/cards?" + q);
        }, null, "table");
        if (!result) {
          this.closeReportDrilldown(false);
          return false;
        }
        this.reportDrilldownRows = result.payload.data || [];
        this.reportDrilldownTotal = Number(result.payload.meta?.total) || 0;
        return true;
      },
      async changeReportDrilldownPage(page) {
        if (this.busy || !Number.isSafeInteger(page) || page < 1 ||
            page > this.reportDrilldownPageCount || page === this.reportDrilldownPage) return;
        this.reportDrilldownPage = page;
        if (await this.loadReportDrilldown()) {
          await this.$nextTick();
          if (this.$refs.reportDrilldownBody) this.$refs.reportDrilldownBody.scrollTop = 0;
        }
      },
      closeReportDrilldown(restoreFocus = true) {
        if (!this.reportDrilldownOpen) return;
        this.reportDrilldownOpen = false;
        this.reportDrilldownRows = [];
        this.reportDrilldownSelection = null;
        document.body.style.overflow = this.reportDrilldownOverflow;
        const trigger = this.reportDrilldownTrigger;
        this.reportDrilldownTrigger = null;
        this.reportDrilldownOverflow = "";
        if (restoreFocus) this.$nextTick(() => {
          const target = trigger?.isConnected ? trigger : document.querySelector(".nav-link.selected");
          target?.focus({ preventScroll: true });
        });
      },
      trapReportDrilldownFocus(event) {
        const modal = this.$refs.reportDrilldownDialog;
        if (!modal) return;
        const elements = [...modal.querySelectorAll(
          'button:not([disabled]), a[href], [tabindex]:not([tabindex="-1"])'
        )].filter(el => el.getClientRects().length);
        if (!elements.length) return;
        const first = elements[0], last = elements[elements.length - 1];
        if (event.shiftKey && (document.activeElement === first ||
            document.activeElement === this.$refs.reportDrilldownHeading)) {
          event.preventDefault(); last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault(); first.focus();
        }
      },
      async fetchReport() {
        const q = new URLSearchParams();
        if (this.reportFrom) q.set("from", this.reportFrom);
        if (this.reportTo) q.set("to", this.reportTo);
        const isAdmin = this.session.user.role === "admin";
        const route = isAdmin ? "admin/reports/" + this.reportGroup : "client/reports/spending";
        if (!isAdmin) q.set("group_by", this.reportClientGroup);
        const res = await this.request("GET", apiRoot + route + (q.size ? "?" + q : ""));
        this.reportData = res.payload;
        this.reportAppliedFrom = this.reportFrom;
        this.reportAppliedTo = this.reportTo;
        if (this.reportCurrencyFilter !== "all" &&
            !this.reportRows.some(row => row.currency === this.reportCurrencyFilter))
          this.reportCurrencyFilter = "all";
      },
      auditUtcInstant(value) {
        // datetime-local has no timezone: interpret its wall-clock fields as UTC,
        // not as the browser's local timezone. Missing seconds mean :00.
        const normalized = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)
          ? value + ":00" : value;
        if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/.test(normalized))
          throw new Error("Enter a complete UTC date and time (hours, minutes and seconds).");
        const timestamp = new Date(normalized + "Z");
        if (Number.isNaN(timestamp.getTime()) ||
          timestamp.toISOString().slice(0, 19) !== normalized)
          throw new Error("Enter a valid UTC date and time.");
        return timestamp;
      },
      async fetchAudit(applyFilters = false) {
        const filters = applyFilters ? {
          action: this.auditAction, actor: this.auditActor, outcome: this.auditOutcome,
          from: this.auditFrom, to: this.auditTo
        } : this.auditAppliedFilters;
        const fromAt = filters.from ? this.auditUtcInstant(filters.from) : null;
        const toAt = filters.to ? this.auditUtcInstant(filters.to) : null;
        if (fromAt && toAt && fromAt > toAt)
          throw new Error("The UTC start time must not be later than the end time.");
        const q = new URLSearchParams({ page: String(this.auditPage), per_page: String(this.auditPerPage) });
        if (filters.action) q.set("action", filters.action);
        if (filters.actor) q.set("actor_id", filters.actor);
        if (filters.outcome) q.set("outcome", filters.outcome);
        if (fromAt) q.set("from", fromAt.toISOString());
        // The API uses an exclusive upper bound; add one second so every event
        // within the chosen ending second (including subsecond timestamps) matches.
        if (toAt) q.set("to", new Date(toAt.getTime() + 1000).toISOString());
        const res = await this.request("GET", apiRoot + "admin/audit_logs?" + q);
        const total = Number(res.payload.meta?.total) || 0;
        if (this.auditPage > 1 && this.auditPage > Math.max(1, Math.ceil(total / this.auditPerPage))) {
          this.auditPage = Math.max(1, Math.ceil(total / this.auditPerPage));
          return this.fetchAudit(applyFilters);
        }
        this.audits = res.payload.data || [];
        this.auditTotal = total;
        if (applyFilters) this.auditAppliedFilters = filters;
        return res;
      },
      async loadProducts() {
        if (this.busy) return;
        if (this.editingProductId !== null && Number(this.productForm.brand_id) !== Number(this.brandId))
          this.resetProduct();
        this.selectedDetail = null;
        this.productPage = 1;
        await this.execute(() => this.fetchProducts(), null, "table");
      },
      async scrollToProductsList() {
        await this.$nextTick();
        this.$refs.productsListTop?.scrollIntoView({
          behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
          block: "start"
        });
      },
      async changeProductPage(nextPage) {
        if (this.busy || this.productCatalogPreview || !Number.isSafeInteger(nextPage) ||
            nextPage < 1 || nextPage > this.productPageCount || nextPage === this.productPage) return;
        const previous = this.productPage;
        this.productPage = nextPage;
        const result = await this.execute(() => this.fetchProducts(), null, "table");
        if (!result) {
          this.productPage = previous;
          return;
        }
        await this.scrollToProductsList();
      },
      async changeProductPerPage() {
        if (this.busy || this.productCatalogPreview) return;
        this.productPage = 1;
        await this.execute(() => this.fetchProducts(), null, "table");
      },
      openAccessPicker() {
        this.accessClientQuery = "";
        this.accessPickerOpen = true;
        this.$nextTick(() => this.$refs.accessClientSearch?.focus());
      },
      async chooseAccessClient(id) {
        if (this.busy || !this.clients.some(c => c.id === Number(id))) return;
        const changed = Number(this.clientId) !== Number(id);
        this.clientId = id;
        this.accessClientQuery = "";
        this.accessPickerOpen = false;
        if (changed) await this.loadGrants();
      },
      async loadGrants() {
        this.accessGrantQuery = "";
        this.accessProductQuery = "";
        await this.execute(() => this.fetchGrants(), null, "table");
      },
      async loadCards() {
        this.cardPage = 1; // Search, Status, and PIN filters always begin on page one.
        await this.execute(() => this.fetchCards(), null, "table");
      },
      async changeCardSort(column) {
        if (this.busy || !["activation_number", "product", "face_value", "payout",
          "status", "has_pin"].includes(column)) return;
        const previous = { column: this.cardSortBy, direction: this.cardSortDir,
          page: this.cardPage };
        this.cardSortDir = this.cardSortBy === column && this.cardSortDir === "asc" ? "desc" : "asc";
        this.cardSortBy = column;
        this.cardPage = 1;
        const result = await this.execute(() => this.fetchCards(), null, "table");
        if (!result) {
          this.cardSortBy = previous.column;
          this.cardSortDir = previous.direction;
          this.cardPage = previous.page;
          return;
        }
        await this.scrollToCardsList();
      },
      async scrollToCardsList() {
        await this.$nextTick();
        this.$refs.cardsListTop?.scrollIntoView({
          behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
          block: "start"
        });
      },
      async changeCardPage(nextPage) {
        if (this.busy || !Number.isSafeInteger(nextPage) ||
            nextPage < 1 || nextPage > this.cardPageCount || nextPage === this.cardPage) return;
        const previous = this.cardPage;
        this.cardPage = nextPage;
        const result = await this.execute(() => this.fetchCards(), null, "table");
        if (!result) {
          this.cardPage = previous;
          return;
        }
        // Page controls are below the table; scroll to the updated list header.
        await this.scrollToCardsList();
      },
      async changeCardPerPage() {
        if (this.busy) return;
        this.cardPage = 1;
        await this.execute(() => this.fetchCards(), null, "table");
      },
      toggleCardPinFilter(mode) {
        if (this.busy || !["with", "without"].includes(mode)) return;
        this.cardPinFilter = this.cardPinFilter === mode ? "" : mode;
        return this.loadCards();
      },
      clearCardFilters() {
        if (this.busy) return;
        this.cardStatus = "";
        this.cardPinFilter = "";
        this.cardQuery = "";
        return this.loadCards();
      },
      async loadCatalog() { await this.execute(() => this.fetchCatalog(), null, "table"); },
      async changeReportGroup() {
        if (this.busy || this.tab !== "reports") return;
        // Do not interpret the previous group's rows as the newly selected group:
        // brand_id and client_id are distinct fields, not interchangeable.
        this.reportData = null;
        this.reportCurrencyFilter = "all";
        await this.loadReport();
      },
      async loadReport() { await this.execute(() => this.fetchReport(), "Report loaded.", "table"); },
      async loadAudit() {
        if (this.busy) return;
        this.auditPage = 1;
        await this.execute(() => this.fetchAudit(true), "Audit filters applied.", "table");
      },
      openAuditDetails(event) {
        if (this.busy) return;
        return this.openDirectoryModal("audit", event);
      },
      clearAuditFilters() {
        if (this.busy) return;
        this.auditAction = "";
        this.auditActor = "";
        this.auditOutcome = "";
        this.auditFrom = "";
        this.auditTo = "";
        this.auditPage = 1;
        return this.execute(() => this.fetchAudit(true), "Audit filters cleared.", "table");
      },
      clearCatalogFilters() {
        this.catalogQuery = "";
        this.catalogCurrency = "";
        this.catalogBrandId = "";
        return this.loadCatalog();
      },
      selectBrand(id) { this.navigateTo("brands-products", id); },
      selectClient(id) { this.navigateTo("grants", id); },
      pickCatalog(item) { return this.navigateTo("issue-product", item.id); },
      createIssueKey() {
        if (this.busy) return;
        if (typeof window.crypto?.randomUUID !== "function")
          return this.notify("Automatic key generation is unavailable. Enter your own unique key.", "error");
        this.issueForm.key = "order-" + window.crypto.randomUUID();
      },
      async scrollToIssueResult() {
        await this.$nextTick();
        const result = this.$refs.issueResult;
        if (!result) return;
        this.$refs.issueResultHeading?.focus({ preventScroll: true });
        result.scrollIntoView({ behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches
          ? "instant" : "smooth", block: "start" });
      },
      async saveBrand() {
        const result = await this.execute(async () => {
          const editing = this.editingBrandId !== null;
          const body = { name: this.brandForm.name, state: this.brandForm.state,
            custom_fields: this.parseFields(this.brandForm.custom_fields) };
          await this.request(editing ? "PATCH" : "POST",
            apiRoot + "admin/brands" + (editing ? "/" + this.editingBrandId : ""), body);
          this.resetBrand();
          await this.fetchBrands();
          this.selectedDetail = null;
          return editing;
        }, editing => editing ? "Brand updated." : "Brand created.");
        await this.scrollToSaveNotice(result);
      },
      async setBrandState(b) {
        const state = b.state === "active" ? "inactive" : "active";
        await this.execute(async () => {
          await this.request("PATCH", apiRoot + "admin/brands/" + b.id, { state });
          await this.fetchBrands();
        }, "Brand updated.");
      },
      async saveProduct() {
        const result = await this.execute(async () => {
          const editing = this.editingProductId !== null;
          const body = { name: this.productForm.name, face_value: this.productForm.face_value,
            currency: this.productForm.currency.trim().toUpperCase(), state: this.productForm.state,
            custom_fields: this.parseFields(this.productForm.custom_fields) };
          const brandId = this.productForm.brand_id;
          await this.request(editing ? "PATCH" : "POST",
            apiRoot + (editing ? "admin/products/" + this.editingProductId :
              "admin/brands/" + brandId + "/products"), body);
          if (Number(this.brandId) !== Number(brandId)) this.productPage = 1;
          this.brandId = brandId;
          this.resetProduct();
          await this.fetchProducts();
          this.selectedDetail = null;
          return editing;
        }, editing => editing ? "Product updated." : "Product created.");
        await this.scrollToSaveNotice(result);
      },
      async setProductState(p) {
        const state = p.state === "active" ? "inactive" : "active";
        await this.execute(async () => {
          await this.request("PATCH", apiRoot + "admin/products/" + p.id, { state });
          await this.fetchProducts();
        }, "Product updated.");
      },
      async removeProduct(p) {
        if (!window.confirm("Soft-delete " + p.name + "? Existing cards remain historically intact.")) return;
        await this.execute(async () => {
          await this.request("DELETE", apiRoot + "admin/products/" + p.id);
          await this.fetchProducts();
        }, "Product soft-deleted.");
      },
      async saveClient() {
        const result = await this.execute(async () => {
          const editing = this.editingClientId !== null;
          const body = { email: this.clientForm.email, payout_rate: this.clientForm.payout_rate,
            active: this.clientForm.active };
          if (this.clientForm.password) body.password = this.clientForm.password;
          await this.request(editing ? "PATCH" : "POST",
            apiRoot + "admin/clients" + (editing ? "/" + this.editingClientId : ""), body);
          this.resetClient();
          await this.fetchClients();
          this.selectedDetail = null;
          return editing;
        }, editing => editing ? "Client updated." : "Client created.");
        await this.scrollToSaveNotice(result);
      },
      async setClientState(c) {
        await this.execute(async () => {
          await this.request("PATCH", apiRoot + "admin/clients/" + c.id, { active: !c.active });
          await this.fetchClients();
        }, "Client status updated.");
      },
      async grantAccess(product) {
        if (!this.clientId || !product || product.deleted_at ||
          this.grants.some(g => Number(g.product_id) === product.id)) return;
        await this.execute(async () => {
          const result = await this.request("POST", apiRoot + "admin/clients/" +
            encodeURIComponent(this.clientId) + "/product_accesses", { product_id: product.id });
          // POST returns the authoritative grant with human-readable associations.
          this.grants = [...this.grants, result.payload.data];
        }, "Access granted to " + product.name + ".");
      },
      async revokeAccess(g) {
        if (!this.clientId || !this.grants.some(item => item.id === g.id)) return;
        if (!window.confirm("Remove " + g.product_name + " from " + g.client_email +
          "? This will block new card issuance, but existing cards stay intact.")) return;
        await this.execute(async () => {
          await this.request("DELETE", apiRoot + "admin/clients/" +
            encodeURIComponent(this.clientId) + "/product_accesses/" + encodeURIComponent(g.product_id));
          this.grants = this.grants.filter(item => item.id !== g.id);
        }, "Access revoked for " + g.product_name + ".");
      },
      async issueCard() {
        if (!this.issueForm.key.trim() || !this.selectedIssueProduct)
          return this.notify("Select an eligible product and enter an idempotency key.", "error");
        const result = await this.execute(async () => {
          const res = await this.request("POST", apiRoot + "client/cards",
            { product_id: Number(this.issueForm.product_id), with_pin: this.issueForm.with_pin },
            this.issueForm.key.trim());
          this.hideIssuedPin();
          this.issued = res.payload.data;
          this.issuedHttpStatus = res.status;
          return res;
        }, res => "Card request accepted: HTTP " + res.status + (res.status === 200 ? " (idempotent replay)." : " (created)."));
        if (result) {
          // Start the next issuance with a clean form, but retain the last Card response.
          // A failed request keeps its inputs so the Client can inspect or correct them.
          this.issueForm = { product_id: "", key: "", with_pin: false };
          this.issueProductQuery = "";
          await this.scrollToIssueResult();
        }
      },
      async cancelCard(c) {
        if (!window.confirm("Cancel " + c.product_name + " (" + c.activation_number + ")? This action cannot be reversed.")) return;
        await this.execute(async () => {
          await this.request("POST", apiRoot + "client/cards/" + c.id + "/cancel");
          if (this.issued?.id === c.id) this.issued = null;
          await this.fetchCards();
        }, "Card cancelled.");
      },
      clearConsolePlaceholderNotice() {
        if (this.flash.kind === "error" &&
            this.flash.text === "Replace the sample ID or REPLACE_WITH value before sending the request.")
          this.flash.text = "";
      },
      applyConsoleTemplate(id) {
        if (this.busy) return;
        this.clearConsolePlaceholderNotice();
        this.consoleTemplateId = id;
        const template = this.selectedConsoleTemplate;
        if (!template) return; // Custom: leave manually edited fields intact.
        this.consoleForm = {
          method: template.method, path: template.path,
          body: template.body ? JSON.stringify(template.body, null, 2) : "",
          key: template.uniqueKey && typeof window.crypto?.randomUUID === "function"
            ? "review-" + window.crypto.randomUUID() : ""
        };
      },
      setConsoleCustom() {
        this.consoleTemplateId = "";
        this.clearConsolePlaceholderNotice();
      },
      async sendConsole() {
        if (this.consoleHasPlaceholders) {
          return this.notify("Replace the sample ID or REPLACE_WITH value before sending the request.", "error");
        }
        await this.execute(async () => {
          const method = this.consoleForm.method;
          const path = this.consoleForm.path;
          let data;
          if (method !== "GET" && this.consoleForm.body.trim()) {
            try { data = JSON.parse(this.consoleForm.body); }
            catch { throw new Error("Body is not valid JSON."); }
            if (!data || typeof data !== "object" || Array.isArray(data)) {
              throw new Error("The JSON body must be an object.");
            }
          }
          try {
            const res = await this.request(method, path, data, this.consoleForm.key);
            this.response = { method, path, body: res.payload, status: res.status, duration: res.duration };
            this.lastApiError = null;
          } catch (error) {
            if (error.status) {
              this.response = { method, path, body: error.body, status: error.status, duration: error.duration };
              this.rememberApiError(error, method, path);
              if (error.status === 401) throw error;
              return; // Render friendly summary; raw response remains in the details modal.
            }
            throw error;
          }
        });
      }
    }
  });

  app.mount("#app");
})();
