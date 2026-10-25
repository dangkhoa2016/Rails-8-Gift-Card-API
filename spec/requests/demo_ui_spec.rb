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
    end

    it "exposes the no-build frontend JavaScript and CSS" do
      get "/demo/app.js"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("window.Vue.createApp")
      expect(response.body).to include("Only same-origin /api/v1/ paths")
      expect(response.body).to include("async saveBrand()", "async saveProduct()", "async saveClient()")
      expect(response.body).to include("async inspect(kind, id)", "reportValue(row, key)")
      get "/demo/style.css"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(".sidebar")
    end
  end

  it "does not replace or relax the protected API authentication" do
    get "/api/v1/client/catalog"
    expect(response).to have_http_status(:unauthorized)
  end
end
