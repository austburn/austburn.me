resource "aws_iam_role_policy" "ecs_instance_policy" {
  name = "ecs_instance_policy"
  role = "${aws_iam_role.ecsInstanceRole.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:CreateCluster",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:StartTelemetrySession",
        "ecs:Submit*",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "s3:GetObject"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "ecs_service" {
  name = "ecs_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_service_policy" {
  name = "ecs_service_policy"
  role = "${aws_iam_role.ecs_service.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ecs" {
  name  = "ecs-instance-profile"
  role  = "${aws_iam_role.ecsInstanceRole.name}"
}

resource "aws_iam_role" "ecsInstanceRole" {
  name = "ecsInstanceRole"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    actions     = ["s3:GetObject"]
    effect      = "Allow"
    resources   = ["arn:aws:s3:::${var.secret_bucket}/*"]
    principals {
      type        = "AWS"
      identifiers = ["${aws_iam_role.ecsInstanceRole.arn}"]
    }
  }

  statement {
    sid         = "DenyUnEncryptedInflightOperations"
    actions     = ["s3:*"]

    resources   = ["arn:aws:s3:::${var.secret_bucket}/*"]

    condition = {
      test      = "Bool"
      variable  = "aws:secureTransport"
      values    = [false]
    }

    principals = {
      type        = "AWS"
      identifiers = ["*"]
    }
  }

  statement {
    sid         = "DenyUnEncryptedObjectUploads"
    actions     = ["s3:PutObject"]
    effect      = "Deny"
    resources   = ["arn:aws:s3:::${var.secret_bucket}/*"]

    condition = {
      test      = "StringNotEquals"
      variable  = "s3:x-amz-server-side-encryption"
      values    = ["AES256"]
    }
    principals = {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_iam_user" "circle_ci_user" {
  name = "circle_ci_user"
}

resource "aws_iam_user_policy" "circle_ci_push" {
  name = "circle_ci_push"
  user = "${aws_iam_user.circle_ci_user.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:DescribeRepositories",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:BatchCheckLayerAvailability"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
