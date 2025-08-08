resource "aws_iam_role_policy_attachment" "ack_lambda_controller_managed_policy" {
  role       = aws_iam_role.home_infrastructure_roles_anywhere_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}
