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
      get "/demo/style.css"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(".sidebar")
      expect(response.body).to include(".entity-link", ".loading-notice", ".btn.processing")
      expect(response.body).to include(".validation-summary", ".field-error")
    end
  end

  it "does not replace or relax the protected API authentication" do
    get "/api/v1/client/catalog"
    expect(response).to have_http_status(:unauthorized)
  end
end
