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

resource "aws_iam_role" "bastion" {
  name = "bastion"
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

resource "aws_iam_role_policy" "bastion_policy" {
  name = "bastion_policy"
  role = "${aws_iam_role.bastion.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "bastion" {
  name  = "bastion"
  role  = "${aws_iam_role.bastion.name}"
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

data "aws_iam_policy_document" "vpc_s3_policy_doc" {
  statement {
    actions     = ["s3:*"]
    effect      = "Deny"
    resources   = ["arn:aws:s3:::${var.secret_bucket}/*"]

    condition = {
      test      = "StringNotEquals"
      variable  = "aws:sourceVpce"
      values    = ["${aws_vpc_endpoint.private_s3.id}"]
    }
  }
}

resource "aws_iam_policy" "vpc_s3_policy" {
  name = "vpc_secrets_policy"
  policy = "${data.aws_iam_policy_document.vpc_s3_policy_doc.json}"
}

data "aws_iam_policy_document" "s3_encryption_policy" {
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
