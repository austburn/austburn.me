resource "aws_iam_user" "circle_ci_user" {
  name = "circle_ci_user"
}

resource "aws_iam_user_policy" "circle_ci_push" {
  name = "circle_ci_push"
  user = aws_iam_user.circle_ci_user.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "iam:PutUserPolicy",
        "route53:*",
        "s3:*",
        "cloudfront:UpdateDistribution"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "circle_ci_read_only" {
  name       = "circle_ci_read_only"
  users      = [aws_iam_user.circle_ci_user.name]
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
