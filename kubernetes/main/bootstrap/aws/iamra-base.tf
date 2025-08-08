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

resource "aws_iam_role" "home_infrastructure_roles_anywhere_role" {
  name = "roles-anywhere-role"
  assume_role_policy = data.aws_iam_policy_document.home_infrastructure_roles_anywhere_assume_role_policy.json
}

data "aws_iam_policy_document" "home_infrastructure_roles_anywhere_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole", "sts:SetSourceIdentity", "sts:TagSession"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["rolesanywhere.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalTag/x509Subject/CN"
      values   = ["ack-s3-controller.aws", "ack-lambda-controller.aws"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values = [aws_rolesanywhere_trust_anchor.home_infrastructure.arn]
    }
  }
}

data "kubernetes_secret" "trust_anchor_certificate" {
  metadata {
    name = "aws-trust-anchor-cert"
    namespace = "aws"
  }
}
