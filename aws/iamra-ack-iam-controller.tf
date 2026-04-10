resource "aws_rolesanywhere_profile" "ack_iam_controller" {
  name      = "ack-iam-controller"
  enabled = true
  role_arns = [aws_iam_role.ack_iam_controller.arn]
}

resource "aws_iam_role" "ack_iam_controller" {
  name = "ack-iam-controller"
  assume_role_policy = data.aws_iam_policy_document.ack_iam_controller.json
}

data "aws_iam_policy_document" "ack_iam_controller" {
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
      values   = ["ack-iam-controller.aws"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values = [aws_rolesanywhere_trust_anchor.home_infrastructure.arn]
    }
  }
}

resource "aws_iam_role_policy" "ack_iam_controller_inline_policy" {
  name = "ack-iam-controller-inline-policy"
  role = aws_iam_role.ack_iam_controller.id
  policy = data.aws_iam_policy_document.ack_iam_controller_inline_policy.json
}

data "aws_iam_policy_document" "ack_iam_controller_inline_policy" {
  statement {
    sid = "IAMRolePermissions"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:PutRolePermissionsBoundary",
      "iam:PutUserPermissionsBoundary",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRoleTags",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy"
    ]
    resources = ["*"]
  }
}
