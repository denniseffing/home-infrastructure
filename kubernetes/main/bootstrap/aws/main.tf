
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

resource "aws_iam_role_policy_attachment" "ack_s3_controller_managed_policy" {
  role       = aws_iam_role.home_infrastructure_roles_anywhere_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "ack_lambda_controller_managed_policy" {
  role       = aws_iam_role.home_infrastructure_roles_anywhere_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

resource "aws_iam_role_policy" "ack_s3_controller_inline_policy" {
  name = "ack-s3-controller-inline-policy"
  role = aws_iam_role.home_infrastructure_roles_anywhere_role.id
  policy = data.aws_iam_policy_document.ack_s3_controller_inline_policy.json
}

data "aws_iam_policy_document" "ack_s3_controller_inline_policy" {
  statement {
    sid = "S3AllPermissions"
    effect = "Allow"
    actions = [
      "s3:*",
      "s3-object-lambda:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "S3ReplicationPassRole"
    effect = "Allow"
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = ["s3.amazonaws.com"]
    }
    actions = ["iam:PassRole"]
    resources = ["*"]
  }
}

resource "aws_rolesanywhere_profile" "ack_s3_controller" {
  name      = "ack-s3-controller"
  enabled = true
  role_arns = [aws_iam_role.home_infrastructure_roles_anywhere_role.arn]
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
  session_policy = data.aws_iam_policy_document.ack_s3_controller_inline_policy.json
}

data "kubernetes_secret" "trust_anchor_certificate" {
  metadata {
    name = "aws-trust-anchor-cert"
    namespace = "aws"
  }
}
