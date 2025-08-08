resource "aws_iam_role_policy_attachment" "ack_s3_controller_managed_policy" {
  role       = aws_iam_role.home_infrastructure_roles_anywhere_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
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
