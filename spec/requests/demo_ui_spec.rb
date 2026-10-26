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
    it "serves the HTML shell with a pinned Vue 3 production CDN global build" do
      get "/demo/index.html"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/html")
      expect(response.body).to include("vue@3.5.22/dist/vue.global.prod.js")
      expect(response.body).to include("/demo/app.js", "/demo/style.css")
      expect(response.body).to include("v-if=\"tab==='console'\"")
      expect(response.body).to include(
        '@submit.prevent="saveBrand"', '@submit.prevent="saveProduct"',
        '@submit.prevent="saveClient"', "inspect('brands',b.id)",
        "inspect('products',p.id)", "inspect('clients',c.id)",
        "g.product_name", "g.client_email", "c.product_name", "c.brand_name"
      )
      expect(response.body).to include(
        "navigateTo('products',g.product_id)", "navigateTo('brands',g.brand_id)",
        "navigateTo('clients',g.client_id)", "navigateTo('catalog-brand',p.brand_id)",
        "navigateTo('issue-product',p.id)", "navigateTo('cards',c.id)",
        'class="loading-notice"', 'class="loading-icon"'
      )
      expect(response.body).to include(
        'class="access-workspace"', 'id="access-client-search"',
        'id="access-client-results"', 'v-for="c in matchingAccessClients.slice(0,8)"',
        '@click="chooseAccessClient(c.id)"', 'v-if="!clientId"',
        'v-model.trim="accessProductQuery"', 'v-model.trim="accessGrantQuery"',
        'v-for="p in availableAccessProducts"', 'v-for="g in matchingAccessGrants"',
        '@click="grantAccess(p)"', '@click="revokeAccess(g)"',
        "navigateTo('clients',accessClient.id)"
      )
      expect(response.body).to include(
        'class="audit-filters"', 'v-model="auditOutcome"', 'v-model="auditFrom"',
        'v-model="auditTo"', '@submit.prevent="loadAudit"', '@click="clearAuditFilters"',
        'To (UTC, inclusive second)', 'type="datetime-local" step="1"',
        'value="success"', 'value="refused"'
      )
      expect(response.body).to include(
        'class="issue-workspace"', 'class="issue-columns"',
        'id="issue-product-search"', 'v-for="p in matchingIssueProducts"',
        '@click="issueForm.product_id=p.id"', '@click="createIssueKey"',
        '@submit.prevent="issueCard"', 'ref="issueResult"',
        'ref="cardDetails"', 'ref="cardDetailsHeading"',
        "@click=\"inspect('cards',c.id)\""
      )
      expect(response.body).not_to include('@submit.prevent="grantAccess"', 'id="access-client-select"')
      expect(response.body).to include(
        "validationErrors.length", "entry.message", "client-email-error",
        "fieldError('email')", "clearFieldError('email')"
      )
    end

    it "exposes the no-build frontend JavaScript and CSS" do
      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("window.Vue.createApp")
      expect(response.body).to include("Only same-origin /api/v1/ paths")
      expect(response.body).to include("async saveBrand()", "async saveProduct()", "async saveClient()")
      expect(response.body).to include("async inspect(kind, id)", "reportValue(row, key)")
      expect(response.body).to include("async navigateTo(kind, rawId)", "entityHref(kind, id)")
      expect(response.body).to include("loadingTable: false", "submitting: false")
      expect(response.body).to include(
        "const collections = { brands: this.brands, clients: this.clients, products: this.products }",
        "const existing = collections[kind].find(record => record.id === Number(id))"
      )
      expect(response.body).to include(
        "validationDetails(error)", "this.validationErrors = this.validationDetails(error)",
        "Email address is already in use. Please enter a different email address."
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
        "auditOutcome: ", "auditFrom: ", "auditTo: ", "auditUtcInstant(value)",
        'q.set("outcome", this.auditOutcome)', 'q.set("from", fromAt.toISOString())',
        'q.set("to", new Date(toAt.getTime() + 1000).toISOString())', "clearAuditFilters()"
      )
      expect(response.body).to include(
        "selectedIssueProduct()", "matchingIssueProducts()", "createIssueKey()",
        "async scrollToCardDetails()", "async scrollToIssueResult()",
        "detail.scrollIntoView(", "result.scrollIntoView(",
        "await this.scrollToCardDetails()", "issuedHttpStatus: null",
        'this.issueForm = { product_id: "", key: "", with_pin: false };',
        'if (result) {', 'await this.scrollToIssueResult()'
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
    end
  end

  it "does not replace or relax the protected API authentication" do
    get "/api/v1/client/catalog"
    expect(response).to have_http_status(:unauthorized)
  end
end
