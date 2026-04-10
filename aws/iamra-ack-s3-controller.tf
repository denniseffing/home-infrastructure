resource "aws_rolesanywhere_profile" "ack_s3_controller" {
  name      = "ack-s3-controller"
  enabled = true
  role_arns = [aws_iam_role.ack_s3_controller.arn]
}

resource "aws_iam_role" "ack_s3_controller" {
  name = "ack-s3-controller"
  assume_role_policy = data.aws_iam_policy_document.ack_s3_controller.json
}

data "aws_iam_policy_document" "ack_s3_controller" {
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
      values   = ["ack-s3-controller.aws"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values = [aws_rolesanywhere_trust_anchor.home_infrastructure.arn]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ack_s3_controller_managed_policy" {
  role       = aws_iam_role.ack_s3_controller.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy" "ack_s3_controller_inline_policy" {
  name = "ack-s3-controller-inline-policy"
  role = aws_iam_role.ack_s3_controller.id
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
