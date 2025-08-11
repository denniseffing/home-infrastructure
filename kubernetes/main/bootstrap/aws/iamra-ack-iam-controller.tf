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
    sid = "IAMAllPermissions"
    effect = "Allow"
    actions = [
      "iam:GetGroup",
      "iam:CreateGroup",
      "iam:DeleteGroup",
      "iam:UpdateGroup",
      "iam:GetRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:PutRolePermissionsBoundary",
      "iam:PutUserPermissionsBoundary",
      "iam:GetUser",
      "iam:CreateUser",
      "iam:DeleteUser",
      "iam:UpdateUser",
      "iam:GetPolicy",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:ListPolicyVersions",
      "iam:ListPolicyTags",
      "iam:ListAttachedGroupPolicies",
      "iam:GetGroupPolicy",
      "iam:PutGroupPolicy",
      "iam:AttachGroupPolicy",
      "iam:DetachGroupPolicy",
      "iam:DeleteGroupPolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListAttachedUserPolicies",
      "iam:ListUserPolicies",
      "iam:GetUserPolicy",
      "iam:PutUserPolicy",
      "iam:AttachUserPolicy",
      "iam:DetachUserPolicy",
      "iam:DeleteUserPolicy",
      "iam:ListRoleTags",
      "iam:ListUserTags",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:TagUser",
      "iam:UntagUser",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviderTags",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:UntagOpenIDConnectProvider",
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:CreateOpenIDConnectProvider",
      "iam:UpdateAssumeRolePolicy"
    ]
    resources = ["*"]
  }
}
