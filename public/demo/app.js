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
    grants: ["Product access", "Grant or revoke Client product entitlements"],
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
        flash: { text: "", kind: "success" },
        loginForm: { email: "", password: "" },
        brands: [], products: [], clients: [], grants: [], catalog: [], cards: [], audits: [],
        brandId: "", clientId: "", grantProductId: "", cardStatus: "",
        editingBrandId: null, editingProductId: null, editingClientId: null,
        selectedDetail: null, cardDetail: null, catalogQuery: "", catalogCurrency: "",
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
      reportKeys() { return [...new Set(this.reportRows.flatMap(row => Object.keys(row)))]; }
    },
    methods: {
      pretty(data) { return data == null ? "{}" : JSON.stringify(data, null, 2); },
      brandName(id) { return this.brands.find(b => b.id === Number(id))?.name || ("Brand #" + id); },
      clientName(id) { return this.clients.find(c => c.id === Number(id))?.email || ("Client #" + id); },
      money(value, currency) { return value + " " + currency; },
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
        const routes = { brands: "admin/brands/", products: "admin/products/",
          clients: "admin/clients/", cards: "client/cards/" };
        if (!routes[kind]) return;
        await this.execute(async () => {
          const res = await this.request("GET", apiRoot + routes[kind] + encodeURIComponent(id));
          if (kind === "cards") this.cardDetail = res.payload.data;
          else this.selectedDetail = { kind, data: res.payload.data };
        });
      },
      notify(message, kind = "success") {
        this.flash = { text: message, kind };
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
      async execute(fn, success) {
        if (this.busy) return;
        this.busy = true;
        this.flash.text = "";
        try {
          const result = await fn();
          if (success) this.notify(typeof success === "function" ? success(result) : success);
          return result;
        } catch (error) {
          if (error.status === 401 && this.session) {
            this.clearSession();
            this.notify("Session expired or account disabled. Sign in again.", "error");
          } else {
            this.notify(this.errorMessage(error), "error");
          }
          return null;
        } finally {
          this.busy = false;
        }
      },
      clearSession() {
        this.session = null;
        this.issued = null;
        this.selectedDetail = null;
        this.cardDetail = null;
        this.editingBrandId = this.editingProductId = this.editingClientId = null;
        this.brands = []; this.products = []; this.clients = []; this.grants = [];
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
        try { await this.request("POST", apiRoot + "auth/logout"); }
        catch { /* Discard local token even when the server is unavailable. */ }
        finally {
          this.clearSession();
          this.busy = false;
          this.notify("Signed out. Your in-memory token has been discarded.");
        }
      },
      async go(section) {
        if (!this.menu.some(item => item.id === section)) return;
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
        });
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
        this.grantProductId = "";
        if (!this.brandId) return;
        const res = await this.request("GET", apiRoot + "admin/brands/" + encodeURIComponent(this.brandId) + "/products?per_page=100");
        this.products = res.payload.data || [];
        if (this.products.length) this.grantProductId = this.products[0].id;
      },
      async fetchClients() {
        const res = await this.request("GET", apiRoot + "admin/clients?per_page=100");
        this.clients = res.payload.data || [];
        if (!this.clients.some(c => c.id === Number(this.clientId)))
          this.clientId = this.clients[0]?.id || "";
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
        await this.execute(() => this.fetchProducts());
      },
      async loadGrants() { await this.execute(() => this.fetchGrants()); },
      async loadCards() { await this.execute(() => this.fetchCards()); },
      async loadCatalog() { await this.execute(() => this.fetchCatalog()); },
      async loadReport() { await this.execute(() => this.fetchReport(), "Report loaded."); },
      async loadAudit() { await this.execute(() => this.fetchAudit(), "Audit filters applied."); },
      selectBrand(id) { this.brandId = id; this.go("products"); },
      selectClient(id) { this.clientId = id; this.go("grants"); },
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
      async grantAccess() {
        if (!this.clientId || !this.grantProductId) return this.notify("Select client and product.", "error");
        await this.execute(async () => {
          await this.request("POST", apiRoot + "admin/clients/" + this.clientId + "/product_accesses",
            { product_id: this.grantProductId });
          await this.fetchGrants();
        }, "Product access granted.");
      },
      async revokeAccess(g) {
        if (!window.confirm("Revoke " + g.product_name + " for " + g.client_email + "?")) return;
        await this.execute(async () => {
          await this.request("DELETE", apiRoot + "admin/clients/" + this.clientId + "/product_accesses/" + g.product_id);
          await this.fetchGrants();
        }, "Product access revoked.");
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
