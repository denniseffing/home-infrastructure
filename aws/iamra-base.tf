resource "aws_rolesanywhere_trust_anchor" "home_infrastructure" {
  name = "home"
  source {
    source_data {
      x509_certificate_data = data.kubernetes_secret.trust_anchor_certificate.data["tls.crt"]
    }
    source_type = "CERTIFICATE_BUNDLE"
  }
  depends_on = [data.kubernetes_secret.trust_anchor_certificate]
  enabled = true
}

data "kubernetes_secret" "trust_anchor_certificate" {
  metadata {
    name = "aws-trust-anchor-cert"
    namespace = "aws"
  }
}
