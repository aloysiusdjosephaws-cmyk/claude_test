// Production (OCI/OKE) — nginx ingress handles both the SPA and API proxying,
// so API calls use the same /api prefix as local development.
export const environment = {
  production: true,
  apiUrl: '/api'
};
