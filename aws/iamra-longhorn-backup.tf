data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  longhorn_backup_bucket_name = "longhorn-backups-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}-an"
}

resource "aws_rolesanywhere_profile" "longhorn_backup" {
  name      = "longhorn-backup"
  enabled   = true
  role_arns = [aws_iam_role.longhorn_backup.arn]
}

resource "aws_iam_role" "longhorn_backup" {
  name               = "longhorn-backup"
  assume_role_policy = data.aws_iam_policy_document.longhorn_backup.json
}

data "aws_iam_policy_document" "longhorn_backup" {
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
      values   = ["longhorn-service-account.longhorn"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_rolesanywhere_trust_anchor.longhorn.arn]
    }
  }
}

resource "aws_iam_role_policy" "longhorn_backup_inline_policy" {
  name   = "longhorn-backup-inline-policy"
  role   = aws_iam_role.longhorn_backup.id
  policy = data.aws_iam_policy_document.longhorn_backup_inline_policy.json
}

data "aws_iam_policy_document" "longhorn_backup_inline_policy" {
  statement {
    sid    = "LonghornBackupstoreAccess"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::${local.longhorn_backup_bucket_name}",
      "arn:aws:s3:::${local.longhorn_backup_bucket_name}/*",
    ]
  }
}

output "longhorn_backup_trust_anchor_arn" {
  value = aws_rolesanywhere_trust_anchor.longhorn.arn
}

output "longhorn_backup_profile_arn" {
  value = aws_rolesanywhere_profile.longhorn_backup.arn
}

output "longhorn_backup_role_arn" {
  value = aws_iam_role.longhorn_backup.arn
}
