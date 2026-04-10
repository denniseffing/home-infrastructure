resource "aws_rolesanywhere_profile" "ack_lambda_controller" {
  name      = "ack-lambda-controller"
  enabled = true
  role_arns = [aws_iam_role.ack_lambda_controller.arn]
}

resource "aws_iam_role" "ack_lambda_controller" {
  name = "ack-lambda-controller"
  assume_role_policy = data.aws_iam_policy_document.ack_lambda_controller.json
}

data "aws_iam_policy_document" "ack_lambda_controller" {
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
      values   = ["ack-lambda-controller.aws"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values = [aws_rolesanywhere_trust_anchor.home_infrastructure.arn]
    }
  }
}

resource "aws_iam_role_policy" "ack_lambda_controller_inline_policy" {
  name = "ack-lambda-controller-inline-policy"
  role = aws_iam_role.ack_lambda_controller.id
  policy = data.aws_iam_policy_document.ack_lambda_controller_inline_policy.json
}

data "aws_iam_policy_document" "ack_lambda_controller_inline_policy" {
  statement {
    sid = "LambdaAllPermissions"
    effect = "Allow"
    actions = [
      "lambda:*",
      "s3:Get*",
      "ecr:Get*",
      "ecr:BatchGet*",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs"
    ]
    resources = ["*"]
  }

  statement {
    sid = "LambdaPassRole"
    effect = "Allow"
    actions = ["iam:PassRole"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = ["lambda.amazonaws.com"]
    }
  }
}
