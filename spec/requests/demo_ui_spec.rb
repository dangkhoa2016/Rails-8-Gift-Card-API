require "rails_helper"

RSpec.describe "Optional Vue reviewer UI", type: :request do
  describe "GET /demo" do
    it "serves the human-facing reviewer workspace as a static directory index" do
      get "/demo"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Gift Card API | Review Workspace")
    end
  end

  describe "static assets" do
    it "uses content hashes for demo JS/CSS and prevents browser caching" do
      get "/demo/index.html"
      expect(response).to have_http_status(:ok)
      expected_js = Digest::SHA256.file(Rails.root.join("public/demo/app.js")).hexdigest.first(12)
      expected_css = Digest::SHA256.file(Rails.root.join("public/demo/style.css")).hexdigest.first(12)
      expect(response.body).to include(%(/demo/app.js?v=#{expected_js}))
      expect(response.body).to include(%(/demo/style.css?v=#{expected_css}))
      expect(response.headers["cache-control"]).to include("no-store")

      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.headers["cache-control"]).to include("no-store")
    end

    it "explains issuance creation, idempotent replay, and key conflicts only in API Console" do
      get "/demo/index.html"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        'v-if="consoleIssuanceOutcome"',
        'consoleIssuanceOutcome.title',
        'consoleIssuanceOutcome.description',
        'consoleIssuanceOutcome.cardId',
        'class="console-error-summary"',
        'v-else class="response-pre tall"'
      )

      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body.dup.force_encoding(Encoding::UTF_8)).to include(
        "consoleIssuanceOutcome()",
        'method !== "POST"',
        '"/api/v1/client/cards"',
        'status === 201',
        'status === 200',
        'status === 409 && body?.error?.code === "idempotency_key_reused"',
        '201 Created — New gift card issued',
        '200 OK — Idempotent replay',
        'Existing Card returned. No new Card was issued.',
        '409 Conflict — Idempotency key reused',
        'No new Card was issued.'
      )

      get "/demo/style.css"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        ".console-issuance-outcome.replay",
        ".console-issuance-outcome.created",
        ".console-issuance-outcome.conflict"
      )
    end

    it "provides role-specific Overview dashboards with safe live counts and shortcuts" do
      get "/demo/index.html"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        'v-if="tab===\'overview\'" class="overview-home"',
        'overview-hero',
        'overviewMetricCards',
        'overviewQuickActions',
        'overviewSteps',
        'overviewStats[metric.key]',
        'overviewLoading',
        'overviewError',
        '@click="loadOverview"',
        'v-for="action in overviewQuickActions"',
        '@click="go(action.tab)"'
      )
      expect(response.body).not_to include('ACCOUNT ROLE</small>', 'BACKEND</small>', 'FRONTEND</small>')

      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        'async loadOverview()',
        'this.overviewRequestId++',
        '++this.overviewRequestId',
        'Promise.allSettled(',
        'admin/brands?page=1&per_page=1',
        'admin/clients?page=1&per_page=1',
        'admin/audit_logs?page=1&per_page=1',
        'client/catalog',
        'client/cards?status=issued&page=1&per_page=1',
        'client/cards?status=cancelled&page=1&per_page=1',
        'this.session?.token !== token',
        'this.tab !== "overview"',
        'if (this.tab === "overview") return this.loadOverview();'
      )
      expect(response.body).not_to include('localStorage.setItem("overview')

      get "/demo/style.css"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        '.overview-hero', '.overview-metrics', '.overview-shortcuts',
        '.overview-steps', '.overview-reassurance', '@media(max-width:520px)'
      )
    end

    it "provides a permission-scoped Client Catalog storefront with read-only discovery" do
      get "/demo/index.html"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "class=\"catalog-workspace\"",
        "catalog-hero",
        "catalog-highlights",
        "catalogBrandOptions.length",
        "catalogCurrencies.length",
        "catalogFeaturedBrands",
        "catalog-brand-chip",
        "catalog-filter-form",
        "catalog-applied",
        "catalogVisibleProducts",
        "catalog-product-card",
        "catalog-product-value",
        "catalogPageCount",
        "catalog-pagination",
        'v-model.number="catalogPerPage"',
        'v-model="catalogSort"',
        'changeCatalogPage(catalogPage+1)',
        'navigateTo(\'catalog-brand\',p.brand_id)',
        'navigateTo(\'issue-product\',p.id)'
      )

      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        'catalogSort: "name", catalogPage: 1, catalogPerPage: 12',
        'catalogDirectoryLoaded: false',
        "catalogBrandOptions()", "catalogFeaturedBrands()", "catalogCurrencies()",
        "catalogVisibleProducts()", "catalogPageCount()", "async changeCatalogPage(page)",
        "async fetchCatalog()", "async fetchIssueCatalog()",
        "this.catalogDirectory = baseline.payload.data;",
        'this.request("GET", apiRoot + "client/catalog?" + params)',
        'params.set("brand_id", String(brandId))',
        "this.catalogAppliedBrandId = brandId;",
        'this.catalogPage = 1;',
        "chooseCatalogBrand(id)",
        "this.catalogQuery = \"\";",
        "this.catalogCurrency = \"\";",
        "this.catalogBrandId = \"\";",
        'await this.go("issue", { selectedProductId: id })'
      )
      expect(response.body).to include(
        'String(a.currency).localeCompare(String(b.currency))',
        'Number(a.face_value) - Number(b.face_value)'
      )

      get "/demo/style.css"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        ".catalog-workspace", ".catalog-hero", ".catalog-highlights",
        ".catalog-brand-chip", ".catalog-product-grid", ".catalog-product-card",
        ".catalog-pagination", "@media(max-width:610px)"
      )
    end

    it "scrolls the API Console to top after successful and failed sends" do
      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      script = response.body
      console_method = script.split("async sendConsole() {", 2).last.split("\n      }", 2).first
      expect(console_method).to include(
        "try {",
        "await this.execute(async () => {",
        "this.response = { method, path, body: res.payload, status: res.status, duration: res.duration };",
        "this.rememberApiError(error, method, path);",
        "finally {",
        "await this.$nextTick();",
        "this.scrollToTop();"
      )
      expect(console_method.index("this.scrollToTop();")).to be > console_method.index("await this.execute(")
      expect(console_method).not_to include("this.consoleForm =")
    end

    it "provides Admin-only Card creation and cancellation templates" do
      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body.dup.force_encoding(Encoding::UTF_8)).to include(
        'id: "admin-issue-card", group: "cards"',
        'id: "admin-cancel-card", group: "cards"',
        'label: "Create a Card for a Client"',
        'label: "Cancel a Client\'s Card"',
        'path: "/api/v1/admin/clients/:client_id/cards"',
        'path: "/api/v1/admin/clients/:client_id/cards/:card_id/cancel"',
        'uniqueKey: true',
        'Create or cancel Cards · Admin actions',
        'this.session?.user?.role',
        'examples.filter(t => t.group === "cards")'
      )
      expect(response.body).to include(
        '/^\\/api\\/v1\\/admin\\/clients\\/[1-9]\\d*\\/cards$/.test(endpoint || "")'
      )
    end

    it "serves the HTML shell with a pinned Vue 3 production CDN global build" do
      get "/demo/index.html"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/html")
      expect(response.body).to include("vue@3.5.22/dist/vue.global.prod.js")
      expect(response.body).to include("/demo/app.js", "/demo/style.css")
      expect(response.body).to include("v-if=\"tab==='console'\"")
      expect(response.body).to include(
        'class="error-modal-overlay"', 'role="dialog"', 'aria-modal="true"',
        'id="error-modal-title"', 'class="response-pre error-modal-raw"',
        '@click="openErrorDetails"', '@click.self="closeErrorDetails"',
        'class="console-error-summary"', "View error details",
        'v-if="response.status>=400"', 'v-else class="response-pre tall"'
      )
      expect(response.body).to include(
        '@submit.prevent="saveBrand"', '@submit.prevent="saveProduct"',
        '@submit.prevent="saveClient"', "inspect('brands',b.id)",
        "inspect('products',p.id)", "inspect('clients',c.id)",
        "g.product_name", "g.client_email", "c.product_name", "c.brand_name"
      )
      expect(response.body).to include(
        "openAccessDetails('products',g.product_id)", "openAccessDetails('brands',g.brand_id)",
        "openAccessDetails('clients',g.client_id)", "navigateTo('catalog-brand',p.brand_id)",
        "navigateTo('issue-product',p.id)", "inspect('cards',c.id)",
        'class="loading-notice"', 'class="loading-icon"'
      )
      expect(response.body).to include(
        'class="access-workspace"', 'id="access-client-search"',
        'id="access-client-results"', 'v-for="c in matchingAccessClients.slice(0,8)"',
        '@click="chooseAccessClient(c.id)"', 'v-if="!clientId"',
        'v-model.trim="accessProductQuery"', 'v-model.trim="accessGrantQuery"',
        'v-for="p in availableAccessProducts"', 'v-for="g in matchingAccessGrants"',
        '@click="grantAccess(p)"', '@click="revokeAccess(g)"',
        "openAccessDetails('clients',accessClient.id)"
      )
      expect(response.body).to include(
        'class="audit-filters"', 'v-model="auditOutcome"', 'v-model="auditFrom"',
        'v-model="auditTo"', '@submit.prevent="loadAudit"', '@click="clearAuditFilters"',
        'To (UTC, inclusive second)', 'type="datetime-local" step="1"',
        'value="success"', 'value="refused"'
      )
      expect(response.body).to include(
        'issueCatalog.length', 'v-if="!issueCatalog.length"',
        "navigateTo('issue-product',p.id)", "navigateTo('catalog-brand',p.brand_id)"
      )
      expect(response.body).to include(
        'class="issue-workspace"', 'class="issue-columns"',
        'id="issue-product-search"', 'v-for="p in matchingIssueProducts"',
        '@click="issueForm.product_id=p.id"', '@click="createIssueKey"',
        '@submit.prevent="issueCard"', 'ref="issueResult"',
        'ref="cardDetails"', 'ref="cardDetailsHeading"',
        "@click=\"inspect('cards',c.id)\""
      )
      expect(response.body).to include(
        'class="panel brand-catalog-panel"', 'id="brand-catalog-select"',
        'id="product-per-page"', 'v-model.number="productPerPage"',
        'ref="productsListTop"', 'productFirst}}', 'productLast}}',
        'of {{productTotal}} products', 'class="card-pagination product-pagination"',
        'aria-label="Brand catalog pagination"', 'v-for="p in productVisiblePages"',
        'changeProductPage(1)', 'changeProductPage(productPage-1)',
        'changeProductPage(productPage+1)', 'changeProductPage(productPageCount)',
        'v-if="productCatalogPreview"', 'Browse all Brand products',
        "@click.prevent=\"navigateTo('products',p.id)\"",
        "@click=\"inspect('products',p.id)\"",
        'v-else-if="directoryModalKind===\'products\'"',
        'directoryModalRecord.brand_id',
        'directoryModalRecord.face_value,directoryModalRecord.currency',
        "directoryModalRecord.deleted_at?'Soft-deleted':directoryModalRecord.state",
        'directoryModalRecord.custom_fields',
        "directoryModalKind==='products'?'Product details'"
      )
      expect(response.body).not_to include(
        'v-if="selectedDetail?.kind===\'products\'" class="record-details"'
      )
      expect(response.body).to include(
        'id="card-search"', 'v-model.trim="cardQuery"',
        '@submit.prevent="loadCards"', 'class="card-search-form"',
        "Search card, Product or Brand", 'id="card-per-page"',
        'v-model.number="cardPerPage"', 'class="card-pagination"',
        'changeCardPage(1)', 'changeCardPage(cardPage-1)',
        'changeCardPage(cardPage+1)', 'changeCardPage(cardPageCount)',
        'ref="cardsListTop"', 'v-for="p in cardVisiblePages"',
        'cardFirst}}', 'cardLast}}', 'of {{cardTotal}} matching cards'
      )
      expect(response.body).to include(
        "changeCardSort('activation_number')", "changeCardSort('product')",
        "changeCardSort('face_value')", "changeCardSort('payout')",
        "changeCardSort('status')", "changeCardSort('has_pin')",
        'class="card-sort-button"', ':aria-sort="cardSortAria(',
        "cardSortLabel('product','Product / Brand')"
      )
      expect(response.body).to include(
        'class="panel report-workspace"', 'class="report-filter-panel"',
        'class="report-stats"', 'class="report-money-grid"',
        "['report-table', {'report-table--grouped':", 'class="report-breakdown"',
        'class="report-col-currency"', 'class="report-col-count"',
        'class="report-col-money"', 'class="report-col-breakdown"',
        'class="report-col-group"',
        'class="report-empty"', 'class="report-raw"',
        'v-model="reportGroup"', 'value="by_brand"', 'value="by_client"',
        'id="report-group" v-model="reportGroup" :disabled="busy" @change="changeReportGroup"',
        'id="report-client-group" v-model="reportClientGroup" :disabled="busy" @change="changeReportGroup"',
        'v-model="reportClientGroup"', 'id="report-client-group"',
        'value="currency"', 'value="brand"',
        'Personal spending', 'id="report-currency"',
        "openReportCards(record,'issued')", "openReportCards(record,'cancelled')",
        'class="report-drilldown-overlay"', 'role="dialog"',
        'aria-labelledby="report-drilldown-title"',
        'class="report-drilldown-table"', 'class="report-drilldown-pages"'
      )
      expect(response.body).to include(
        'id="console-template"', 'v-model="consoleTemplateId"',
        '@change="applyConsoleTemplate(consoleTemplateId)"',
        'v-for="group in consoleTemplateGroups"',
        'v-for="example in group.items"',
        'id="console-method"', 'id="console-endpoint"',
        '@change="setConsoleCustom"', '@input="setConsoleCustom"',
        'class="console-placeholder-warning"', 'class="console-write-warning"',
        ':disabled="busy||consoleHasPlaceholders"'
      )
      expect(response.body).to include(
        'class="back-to-top"', 'aria-label="Scroll to top"',
        'v-show="showBackToTop && !cardModalOpen && !reportDrilldownOpen && !errorModalOpen && !directoryModalKind"',
        '@click="scrollToTop"'
      )
      expect(response.body).to include(
        'ref="brandsListTop"', 'ref="clientsListTop"', 'ref="auditListTop"',
        'id="brands-per-page"', 'id="clients-per-page"', 'id="audit-per-page"',
        'aria-label="Brands pagination"', 'aria-label="Clients pagination"',
        'aria-label="Audit pagination"', 'openAuditDetails(e)',
        'class="directory-detail-overlay"', 'class="directory-detail-dialog"',
        'ref="directoryModalHeading"', '@keydown.tab="trapDirectoryModalFocus"',
        'directoryModalRecord.actor_email', 'directory-detail-json'
      )
      expect(response.body).to include(
        'class="card-modal-overlay"', 'class="card-detail-modal"',
        'id="card-detail-modal-title"', '@keydown.tab="trapCardModalFocus"',
        '@keydown.esc.stop.prevent="closeCardDetails()"', '@click.self="closeCardDetails()"'
      )
      expect(response.body).to include(
        'class="card-pin-filters"', 'v-model="cardStatus"',
        "cardPinFilter==='with'", "cardPinFilter==='without'",
        "toggleCardPinFilter('with')", "toggleCardPinFilter('without')",
        'c.has_pin', 'cardDetail.has_pin', '@click="clearCardFilters"'
      )
      expect(response.body).to include(
        "issuedPinVisible?issued.pin:", "issuedPinVisible?'Hide PIN':'Reveal PIN'",
        'ref="pinPasswordInput"', '@submit.prevent="revealCardPin"',
        'v-if="revealedCardPin"', 'Automatically hidden after 30 seconds'
      )
      expect(response.body).to include(
        'id="pin-reveal-error"', 'class="field-error pin-reveal-error"',
        'role="alert"', ':aria-invalid="!!pinRevealError"',
        "@input=\"pinRevealError=''\""
      )
      expect(response.body).not_to include('PIN: {{issued.pin}}')
      expect(response.body).not_to include('@submit.prevent="grantAccess"', 'id="access-client-select"')
      expect(response.body).to include(
        "validationErrors.length", "entry.message", "client-email-error",
        "fieldError('email')", "clearFieldError('email')"
      )
    end

    it "keeps Product access entity details in read-only modals" do
      get "/demo/index.html"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "openAccessDetails('clients',accessClient.id)",
        "openAccessDetails('products',p.id)",
        "openAccessDetails('brands',p.brand_id)",
        "openAccessDetails('products',g.product_id)",
        "openAccessDetails('brands',g.brand_id)",
        "openAccessDetails('clients',g.client_id)"
      )
      expect(response.body).to include(
        "tab==='grants' ? openAccessDetails('brands',directoryModalRecord.brand_id)",
        'class="directory-detail-dialog"'
      )

      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "async openAccessDetails(kind, rawId)",
        'this.tab !== "grants"',
        'this.directoryModalRecord = record',
        'await this.openDirectoryModal(kind, record)'
      )
    end

    it "opens Audit Record and Financial report grouping links in fetched details modals" do
      get "/demo/index.html"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "openAdminRelatedDetails('brands',record.brand_id)",
        "openAdminRelatedDetails('clients',record.client_id)",
        "openAuditRecordDetails(e)",
        'directoryModalKind===\'access\'?',
        "Product access details",
        "Current permission",
        "Not currently granted (revoked)"
      )
      expect(response.body).not_to include(
        "@click.prevent=\"navigateTo(auditEntity(e).kind,auditEntity(e).id)\"",
        "@click.prevent=\"navigateTo('brands',record.brand_id)\"",
        "@click.prevent=\"navigateTo('clients',record.client_id)\""
      )

      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "async openAdminRelatedDetails(kind, rawId)",
        "async openAuditRecordDetails(event)",
        '["audit", "reports"].includes(this.tab)',
        'this.request("GET", apiRoot + "admin/" + kind + "/" + id)',
        'this.fetchFullAdminDirectory("clients/" + clientId + "/product_accesses")',
        'response.data.find(grant => Number(grant.id) === accessId)',
        'this.openDirectoryModal("access", {',
        'previousScrollY = window.scrollY',
        'window.scrollTo({ top: previousScrollY, behavior: "instant" })'
      )
    end

    it "links ProductAccess Brand details without redirecting from Audit logs" do
      get "/demo/index.html"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        'v-else-if="directoryModalKind===\'access\'"',
        'v-if="directoryModalRecord.brand_id" class="entity-link"',
        'entityHref(\'brands\',directoryModalRecord.brand_id)',
        'openAdminRelatedDetails(\'brands\',directoryModalRecord.brand_id)'
      )

      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        'let brandId = Number(activeGrant?.brand_id) || null;',
        'this.fetchProductWithBrand(productId)',
        'brand_id: brandId, brand_name: brandLabel,',
        'await this.openDirectoryModal("access", {',
        'this.request("GET", apiRoot + "admin/brands/" + brandId)',
        'return { ...product, brand_name: brand.payload.data.name };'
      )
      expect(response.body).to include('if (kind === "products") return this.fetchProductWithBrand(id);')

      get "/demo/index.html"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        '{{directoryModalRecord.brand_name || brandName(directoryModalRecord.brand_id)}}'
      )
    end

    it "loads complete Product access permissions across every API page" do
      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "async fetchFullAdminDirectory(resource)",
        'page: "1", per_page: "100"',
        "Math.ceil(total / 100)",
        "records.length !== total",
        "new Set(records.map(item => item.id)).size !== total",
        'this.accessGrantsLoadedClientId = null;',
        'this.accessProductsLoadedBrandId = null;',
        '"brands/" + encodeURIComponent(brandId) + "/products"',
        '"clients/" + encodeURIComponent(clientId) + "/product_accesses"',
        "this.accessGrantsLoadedClientId = clientId;",
        "this.accessProductsLoadedBrandId = brandId;",
        "accessGrantsReady()", "accessProductsReady()"
      )
      expect(response.body).not_to include(
        '"admin/clients/" + encodeURIComponent(this.clientId) + "/product_accesses?per_page=100"'
      )

      get "/demo/index.html"
      expect(response).to have_http_status(:ok)
      expect(response.body.dup.force_encoding(Encoding::UTF_8)).to include(
        "accessGrantsReady?grants.length:'—'",
        "accessGrantsReady&&accessProductsReady?availableAccessProducts.length:'—'",
        "The complete Product or Grant list is unavailable.",
        "The complete Grant list is unavailable.",
        "All Clients, Products for the selected Brand"
      )
    end

    it "starts each Product access visit with empty STEP 02 filters" do
      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        'if (section === "grants") {',
        'this.brandId = "";',
        'this.accessProductQuery = "";',
        'this.products = [];',
        'this.accessProductsLoadedBrandId = null;',
        'this.brandId = this.tab === "grants" ? "" : (this.brands[0]?.id || "");'
      )
      expect(response.body).to include(
        'if (section === "grants" && !preserveGrantClient && this.tab !== section) {',
        'this.accessPickerOpen = false;'
      )
    end

    it "scrolls to a failed Grant error and avoids unnecessary Product access spacing" do
      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "async grantAccess(product)",
        "const outcome = await this.execute(async () => {",
        "if (outcome === null) {",
        "this.scrollToTop();"
      )

      get "/demo/style.css"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("scrollbar-gutter:auto;padding:2px 0 3px")
      expect(response.body).not_to match(/\.access-list\{[^}]*scrollbar-gutter:stable/)
    end

    it "exposes the no-build frontend JavaScript and CSS" do
      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("window.Vue.createApp")
      expect(response.body).to include("Only same-origin /api/v1/ paths")
      expect(response.body).to include("async saveBrand()", "async saveProduct()", "async saveClient()")
      expect(response.body).to include("async inspect(kind, id)", "reportValue(row, key)")
      expect(response.body).to include("async navigateTo(kind, rawId)", "entityHref(kind, id)")
      expect(response.body).to include(
        'error?.body?.error?.code !== "validation_failed"',
        "safeRawError(value)", "rememberApiError(error, method, path)",
        "async openErrorDetails()", "closeErrorDetails()", "route_not_found",
        "this.rememberApiError(error, method, path);", "lastApiError: null"
      )
      expect(response.body).to include("loadingTable: false", "submitting: false")
      expect(response.body).to include(
        'productPage: 1, productPerPage: 25, productTotal: 0',
        'productCatalogPreview: false', 'productPageCount()', 'productVisiblePages()',
        'productFirst()', 'productLast()', 'async changeProductPage(nextPage)',
        'async changeProductPerPage()', 'async scrollToProductsList()',
        'this.tab === "products"', 'const perPage = catalog ? this.productPerPage : 100',
        'this.productTotal = total;', 'this.productCatalogPreview = false;'
      )
      expect(response.body).to include(
        'id: "admin-brands"', 'id: "admin-report-brand"',
        'id: "admin-audit"', 'id: "admin-create-brand"',
        'id: "client-catalog"', 'id: "client-cards"',
        'id: "client-spending"', 'id: "client-issue"',
        'consoleTemplateGroups()', 'selectedConsoleTemplate()',
        'consoleHasPlaceholders()', 'applyConsoleTemplate(id)',
        'setConsoleCustom()', 'this.consoleTemplateId = "";',
        'this.session.user.role === "admin" ? "admin-brands" : "client-catalog"'
      )
      expect(response.body).to include(
        "showBackToTop: false", 'mounted() {',
        'window.addEventListener("scroll", this.updateBackToTop, { passive: true });',
        'window.removeEventListener("scroll", this.updateBackToTop);',
        'this.showBackToTop = window.scrollY > 360;',
        'scrollToTop() {', 'window.scrollTo({'
      )
      expect(response.body).to include(
        'cardPage: 1, cardPerPage: 25, cardTotal: 0',
        'cardSortBy: "", cardSortDir: "asc"',
        'cardPageCount()', 'cardVisiblePages()', 'async changeCardPage(nextPage)',
        'this.$refs.cardsListTop?.scrollIntoView(', 'async changeCardPerPage()',
        'async changeCardSort(column)', 'cardSortAria(column)', 'cardSortIcon(column)',
        'this.cardPage = 1;',
        'this.cardTotal = Number(res.payload.meta?.total) || 0;'
      )
      expect(response.body).to include(
        'reportPreset: "all"', 'reportCurrencyFilter: "all"',
        'reportCurrencySummaries()', 'reportVisibleRows()', 'async changeReportGroup()',
        'this.reportData = null;', 'this.reportCurrencyFilter = "all";',
        'chooseReportPreset(preset)', 'reportCents(value)',
        'reportFormattedCents(cents, currency)', 'reportClientGroup: "currency"',
        'q.set("group_by", this.reportClientGroup)',
        'async openReportCards(row, event)', 'async loadReportDrilldown()',
        'async changeReportDrilldownPage(page)', 'closeReportDrilldown(restoreFocus = true)',
        'this.closeReportDrilldown(false);'
      )
      expect(response.body).to include(
        "const collections = { brands: this.brands, products: this.products,",
        "const existing = collections[kind].find(record => record.id === Number(id))"
      )
      expect(response.body).to include(
        "validationDetails(error)", "this.validationErrors = this.validationDetails(error)",
        "Email address is already in use. Please enter a different email address."
      )
      expect(response.body).to include(
        "catalog: [], issueCatalog: []", "return this.issueCatalog.find(",
        "return this.issueCatalog.filter(",
        'this.go("issue", { selectedProductId: id })',
        'this.go("catalog", { brandId: id })',
        "async fetchIssueCatalog()", 'this.issueCatalog = res.payload.data || [];',
        'if (this.tab === "catalog") {', 'this.catalogDirectoryLoaded = false;',
        'if (this.tab === "issue") await this.fetchIssueCatalog();',
        'this.catalogBrandId = brandId || "";',
        'this.issueForm.product_id = selectedProductId || "";'
      )
      expect(response.body).not_to include(
        'if (["catalog", "issue"].includes(this.tab)) await this.fetchCatalog();',
        'return this.catalog.find(p => p.id === Number(this.issueForm.product_id))',
        'return this.catalog.filter(p => [p.name, p.brand_name, p.currency, p.face_value]'
      )
      expect(response.body).to include(
        "matchingAccessClients()", "availableAccessProducts()", "matchingAccessGrants()",
        "openAccessPicker()", "async chooseAccessClient(id)",
        "this.accessPickerOpen = false",
        "async grantAccess(product)", "async revokeAccess(g)",
        "this.grants = [...this.grants, result.payload.data]",
        "this.grants = this.grants.filter(item => item.id !== g.id)"
      )
      expect(response.body).to include(
        'brandPage: 1, brandPerPage: 25, brandTotal: 0',
        'clientPage: 1, clientPerPage: 25, clientTotal: 0',
        'auditPage: 1, auditPerPage: 25, auditTotal: 0',
        'changeDirectoryPage(kind, next)', 'changeDirectoryPerPage(kind)',
        'openDirectoryModal(kind, record, previousScrollY = window.scrollY)', 'closeDirectoryModal(restoreFocus = true)',
        'trapDirectoryModalFocus(event)', 'safeAuditFields(data)',
        'fetchFullAdminDirectory(resource)', 'this.auditAppliedFilters = filters;',
        'await this.openDirectoryModal(kind, existing);',
        '["brands", "clients", "products", "audit", "access"].includes(kind)',
        'if (this.tab === "products") {',
        'await this.inspect(kind, id);',
        'await this.openDirectoryModal(kind, record);',
        '["brands", "clients", "products"].includes(kind) && result'
      )
      expect(response.body).to include(
        "auditOutcome: ", "auditFrom: ", "auditTo: ", "auditUtcInstant(value)",
        'q.set("outcome", filters.outcome)', 'q.set("from", fromAt.toISOString())',
        'q.set("to", new Date(toAt.getTime() + 1000).toISOString())', "clearAuditFilters()"
      )
      expect(response.body).to include(
        "selectedIssueProduct()", "matchingIssueProducts()", "createIssueKey()",
        "async openCardDetails()", "async scrollToIssueResult()",
        "cardModalOpen = true", "result.scrollIntoView(",
        "await this.openCardDetails()", "issuedHttpStatus: null",
        'this.issueForm = { product_id: "", key: "", with_pin: false };',
        'if (result) {', 'await this.scrollToIssueResult()'
      )
      expect(response.body).to include(
        'cardPinFilter: "", cardQuery: ""',
        'if (this.cardQuery.trim()) q.set("q", this.cardQuery.trim());',
        'await this.go("cards");', 'this.cardDetail = card;',
        'this.cards = [];', 'this.cardQuery = "";'
      )
      expect(response.body).not_to include('this.cards = [result.payload.data];')
      expect(response.body).to include(
        "cardPinFilter: ", "toggleCardPinFilter(mode)", "clearCardFilters()",
        'q.set("has_pin", this.cardPinFilter === "with" ? "true" : "false")'
      )
      expect(response.body).to include(
        "hideIssuedPin()", "showIssuedPin()", "hideCardPin()", "async revealCardPin()",
        "this.revealedCardPin = res.payload.data.pin", "issuedPinVisible: false",
        '"/reveal_pin", { password }'
      )
      expect(response.body).to include(
        'pinRevealError: ""', 'inlinePinError = false',
        'this.pinRevealError = this.errorMessage(error)',
        '"PIN displayed for up to 30 seconds.", "submit", true',
        'this.pinRevealError = ""'
      )
      expect(response.body).not_to include("grantProductId")
      get "/demo/style.css"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(".sidebar")
      expect(response.body).to include(".entity-link", ".loading-notice", ".btn.processing")
      expect(response.body).to include(".validation-summary", ".field-error")
      expect(response.body).to include(".access-workspace", ".access-columns", ".access-item")
      expect(response.body).to include(".access-client-results", ".access-client-option")
      expect(response.body).to include(".audit-filters", ".audit-filter-actions")
      expect(response.body).to include(".issue-columns", ".issue-product-choice", ".card-details")
      expect(response.body).to include(".card-pin-options", ".card-pin-badge", ".card-filter-bar")
      expect(response.body).to include(".card-pin-reveal-form .pin-reveal-error")
      expect(response.body).to include(".error-modal-overlay", ".console-error-summary")
      expect(response.body).to include(".card-search-form", "nav.card-pagination", ".card-modal-overlay", ".card-detail-modal")
      expect(response.body).to include(".card-sort-button", ".card-sort-icon")
      expect(response.body).to include(".back-to-top", ".back-to-top:focus-visible")
      expect(response.body).to include(".product-pagination-summary", ".product-preview-notice")
      expect(response.body).to include(".console-template-box", ".console-template-kind",
        ".console-placeholder-warning", ".console-write-warning", ".console-method-path")
      expect(response.body).to include(".report-workspace", ".report-filter-form",
        ".report-money-grid", ".report-money-card", ".report-stats",
        ".report-table--grouped th.report-col-group",
        ".report-table th.report-col-count,.report-table td.report-col-count",
        ".report-table th.report-col-money,.report-table td.report-col-money")
    end
  end

  it "does not replace or relax the protected API authentication" do
    get "/api/v1/client/catalog"
    expect(response).to have_http_status(:unauthorized)
  end
end
