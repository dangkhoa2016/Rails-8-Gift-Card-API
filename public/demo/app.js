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

  const app = window.Vue.createApp({
    data() {
      return {
        tab: "overview", session: null, busy: false,
        loadingTable: false, loadingDetail: false, submitting: false,
        flash: { text: "", kind: "success" },
        validationErrors: [],
        loginForm: { email: "", password: "" },
        brands: [], products: [], clients: [], grants: [], catalog: [], cards: [], audits: [],
        brandId: "", clientId: "", cardStatus: "",
        accessClientQuery: "", accessPickerOpen: false, accessProductQuery: "", accessGrantQuery: "",
        editingBrandId: null, editingProductId: null, editingClientId: null,
        selectedDetail: null, cardDetail: null, catalogQuery: "", catalogCurrency: "",
        catalogBrandId: "",
        brandForm: { name: "", state: "active", custom_fields: "{}" },
        productForm: { brand_id: "", name: "", face_value: "100.00", currency: "USD", state: "active", custom_fields: "{}" },
        clientForm: { email: "", password: "", payout_rate: "90", active: true },
        issueForm: { product_id: "", key: "", with_pin: false },
        issued: null,
        reportFrom: "", reportTo: "", reportGroup: "by_brand", reportData: null,
        auditAction: "", auditActor: "",
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
      heading() { return sections[this.tab][0]; },
      hint() { return sections[this.tab][1]; },
      reportRows() { return Array.isArray(this.reportData?.data) ? this.reportData.data : []; },
      reportKeys() { return [...new Set(this.reportRows.flatMap(row => Object.keys(row)))]; },
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
    methods: {
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
          this.catalogBrandId = id;
          this.catalogQuery = "";
          this.catalogCurrency = "";
          await this.go("catalog");
        } else if (kind === "issue-product" && !admin) {
          this.issueForm.product_id = id;
          await this.go("issue");
        } else if (kind === "cards" && !admin) {
          // A card row already has all the fields in the detail response.
          const card = this.cards.find(item => item.id === id);
          if (card) {
            this.tab = "cards";
            this.cardDetail = card;
            this.selectedDetail = null;
          } else {
            const result = await this.execute(
              () => this.request("GET", apiRoot + "client/cards/" + id), null, "detail");
            if (!result) return;
            this.tab = "cards";
            this.cardDetail = result.payload.data;
            this.cards = [result.payload.data];
          }
        } else if (admin && kind === "brands-products") {
          this.brandId = id;
          await this.go("products");
        } else if (admin && kind === "grants") {
          this.clientId = id;
          this.accessClientQuery = "";
          this.accessPickerOpen = false;
          await this.go("grants", true);
        } else if (admin && ["brands", "clients", "products"].includes(kind)) {
          // The directory index and show endpoints serialize identical fields.
          // Prefer the current directory row; for uncached cross-page targets,
          // fetch only the target detail rather than refetching two lists.
          const collections = { brands: this.brands, clients: this.clients, products: this.products };
          let record = collections[kind].find(item => item.id === id);
          if (!record) {
            const result = await this.execute(
              () => this.request("GET", apiRoot + "admin/" + kind + "/" + id), null, "detail");
            if (!result) return;
            record = result.payload.data;
            // Show the fetched record without presenting the old brand's product list.
            if (kind === "products") this.products = [record];
            else collections[kind].push(record);
          }
          if (kind === "products") this.brandId = record.brand_id;
          this.tab = kind;
          this.selectedDetail = { kind, data: record };
          this.cardDetail = null;
        }
      },
      reportValue(row, key) {
        if (key === "brand_id") return this.brandName(row[key]);
        if (key === "client_id") return this.clientName(row[key]);
        return row[key] ?? "—";
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
      },
      editProduct(record) {
        this.editingProductId = record.id;
        this.productForm = { brand_id: record.brand_id, name: record.name,
          face_value: record.face_value, currency: record.currency, state: record.state,
          custom_fields: this.pretty(record.custom_fields || {}) };
      },
      editClient(record) {
        this.editingClientId = record.id;
        this.clientForm = { email: record.email, password: "",
          payout_rate: record.payout_rate, active: record.active };
      },
      async inspect(kind, id) {
        if (this.busy) return;
        const routes = { brands: "admin/brands/", products: "admin/products/",
          clients: "admin/clients/", cards: "client/cards/" };
        if (!routes[kind]) return;
        const collections = { brands: this.brands, products: this.products,
          clients: this.clients, cards: this.cards };
        const existing = collections[kind].find(record => record.id === Number(id));
        if (existing) {
          if (kind === "cards") this.cardDetail = existing;
          else this.selectedDetail = { kind, data: existing };
          return;
        }
        // A deep-linked or paginated-out record is the only case needing GET show.
        await this.execute(async () => {
          const res = await this.request("GET", apiRoot + routes[kind] + encodeURIComponent(id));
          if (kind === "cards") this.cardDetail = res.payload.data;
          else this.selectedDetail = { kind, data: res.payload.data };
        }, null, "detail");
      },
      notify(message, kind = "success") {
        this.flash = { text: message, kind };
      },
      validationDetails(error) {
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
        return error?.body?.error?.message || error?.message || "Unexpected request failure";
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
          throw err;
        }
        return { status: res.status, payload, duration };
      },
      async execute(fn, success, mode = "submit") {
        if (this.busy) return null;
        this.busy = true;
        this.loadingTable = mode === "table";
        this.loadingDetail = mode === "detail";
        this.submitting = mode === "submit";
        this.flash.text = "";
        this.validationErrors = [];
        try {
          const result = await fn();
          if (success) this.notify(typeof success === "function" ? success(result) : success);
          return result;
        } catch (error) {
          if (error.status === 401 && this.session) {
            this.clearSession();
            this.notify("Session expired or account disabled. Sign in again.", "error");
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
        this.validationErrors = [];
        this.session = null;
        this.loadingTable = false;
        this.loadingDetail = false;
        this.submitting = false;
        this.issued = null;
        this.selectedDetail = null;
        this.cardDetail = null;
        this.editingBrandId = this.editingProductId = this.editingClientId = null;
        this.brands = []; this.products = []; this.clients = []; this.grants = [];
        this.clientId = ""; this.accessClientQuery = ""; this.accessPickerOpen = false;
        this.accessProductQuery = ""; this.accessGrantQuery = "";
        this.catalog = []; this.cards = []; this.audits = [];
        this.loginForm.email = "";
        this.loginForm.password = "";
        this.consoleForm.body = "";
        this.consoleForm.key = "";
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
      async go(section, preserveGrantClient = false) {
        if (this.busy || !this.menu.some(item => item.id === section)) return;
        // Navigation from a Client or Audit link retains the targeted Client;
        // a direct menu visit asks for an explicit Client selection.
        if (section === "grants" && !preserveGrantClient && this.tab !== section) {
          this.clientId = "";
          this.accessClientQuery = "";
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
            if (["catalog", "issue"].includes(this.tab)) await this.fetchCatalog();
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
      async fetchBrands() {
        const res = await this.request("GET", apiRoot + "admin/brands?per_page=100");
        this.brands = res.payload.data || [];
        if (!this.brands.some(b => b.id === Number(this.brandId))) this.brandId = this.brands[0]?.id || "";
        if (!this.editingProductId && !this.brands.some(b => b.id === Number(this.productForm.brand_id)))
          this.productForm.brand_id = this.brands[0]?.id || "";
      },
      async fetchProducts() {
        this.products = [];
        if (!this.brandId) return;
        const res = await this.request("GET", apiRoot + "admin/brands/" + encodeURIComponent(this.brandId) + "/products?per_page=100");
        this.products = res.payload.data || [];
      },
      async fetchClients() {
        const res = await this.request("GET", apiRoot + "admin/clients?per_page=100");
        this.clients = res.payload.data || [];
        if (!this.clients.some(c => c.id === Number(this.clientId)))
          this.clientId = this.tab === "grants" ? "" : (this.clients[0]?.id || "");
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
        if (this.catalog.length && !this.catalog.some(p => p.id === Number(this.issueForm.product_id))) {
          this.issueForm.product_id = this.catalog[0].id;
        }
        if (!this.catalog.length) this.issueForm.product_id = "";
      },
      async fetchCards() {
        const q = new URLSearchParams({ per_page: "100" });
        if (this.cardStatus) q.set("status", this.cardStatus);
        const res = await this.request("GET", apiRoot + "client/cards?" + q);
        this.cards = res.payload.data || [];
      },
      async fetchReport() {
        const q = new URLSearchParams();
        if (this.reportFrom) q.set("from", this.reportFrom);
        if (this.reportTo) q.set("to", this.reportTo);
        const route = this.session.user.role === "admin"
          ? "admin/reports/" + this.reportGroup : "client/reports/spending";
        const res = await this.request("GET", apiRoot + route + (q.size ? "?" + q : ""));
        this.reportData = res.payload;
      },
      async fetchAudit() {
        const q = new URLSearchParams({ per_page: "50" });
        if (this.auditAction) q.set("action", this.auditAction);
        if (this.auditActor) q.set("actor_id", this.auditActor);
        const res = await this.request("GET", apiRoot + "admin/audit_logs?" + q);
        this.audits = res.payload.data || [];
      },
      async loadProducts() {
        if (this.editingProductId !== null && Number(this.productForm.brand_id) !== Number(this.brandId))
          this.resetProduct();
        this.selectedDetail = null;
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
      async loadCards() { await this.execute(() => this.fetchCards(), null, "table"); },
      async loadCatalog() { await this.execute(() => this.fetchCatalog(), null, "table"); },
      async loadReport() { await this.execute(() => this.fetchReport(), "Report loaded.", "table"); },
      async loadAudit() { await this.execute(() => this.fetchAudit(), "Audit filters applied.", "table"); },
      clearCatalogFilters() {
        this.catalogQuery = "";
        this.catalogCurrency = "";
        this.catalogBrandId = "";
        return this.loadCatalog();
      },
      selectBrand(id) { this.navigateTo("brands-products", id); },
      selectClient(id) { this.navigateTo("grants", id); },
      pickCatalog(item) { this.issueForm.product_id = item.id; this.go("issue"); },
      async saveBrand() {
        await this.execute(async () => {
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
      },
      async setBrandState(b) {
        const state = b.state === "active" ? "inactive" : "active";
        await this.execute(async () => {
          await this.request("PATCH", apiRoot + "admin/brands/" + b.id, { state });
          await this.fetchBrands();
        }, "Brand updated.");
      },
      async saveProduct() {
        await this.execute(async () => {
          const editing = this.editingProductId !== null;
          const body = { name: this.productForm.name, face_value: this.productForm.face_value,
            currency: this.productForm.currency.trim().toUpperCase(), state: this.productForm.state,
            custom_fields: this.parseFields(this.productForm.custom_fields) };
          const brandId = this.productForm.brand_id;
          await this.request(editing ? "PATCH" : "POST",
            apiRoot + (editing ? "admin/products/" + this.editingProductId :
              "admin/brands/" + brandId + "/products"), body);
          this.brandId = brandId;
          this.resetProduct();
          await this.fetchProducts();
          this.selectedDetail = null;
          return editing;
        }, editing => editing ? "Product updated." : "Product created.");
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
        await this.execute(async () => {
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
        if (!this.issueForm.key || !this.issueForm.product_id) return this.notify("Product and idempotency key required.", "error");
        await this.execute(async () => {
          const res = await this.request("POST", apiRoot + "client/cards",
            { product_id: Number(this.issueForm.product_id), with_pin: this.issueForm.with_pin },
            this.issueForm.key);
          this.issued = res.payload.data;
          return res;
        }, res => "Card request accepted: HTTP " + res.status + (res.status === 200 ? " (idempotent replay)." : " (created)."));
      },
      async cancelCard(c) {
        if (!window.confirm("Cancel " + c.product_name + " (" + c.activation_number + ")? This action cannot be reversed.")) return;
        await this.execute(async () => {
          await this.request("POST", apiRoot + "client/cards/" + c.id + "/cancel");
          if (this.issued?.id === c.id) this.issued = null;
          await this.fetchCards();
        }, "Card cancelled.");
      },
      async sendConsole() {
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
          } catch (error) {
            if (error.status) {
              this.response = { method, path, body: error.body, status: error.status, duration: error.duration };
              if (error.status === 401) throw error;
              return; // Display expected negative-test 4xx responses without losing the console view.
            }
            throw error;
          }
        });
      }
    }
  });

  app.mount("#app");
})();
