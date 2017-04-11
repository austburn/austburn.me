provider "aws" {
    region = "us-east-2"
}

resource "aws_iam_role_policy" "ecs_policy" {
  name = "ecs_policy"
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
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
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
»

resource "aws_ecs_cluster" "cluster" {
    name = "web"
}

resource "aws_ecs_service" "web" {
    name          = "web-service"
    cluster       = "${aws_ecs_cluster.cluster.id}"
    desired_count = 2
    iam_role      = "${aws_iam_role.ecsInstanceRole.arn}"
    depends_on    = ["aws_iam_role_policy.ecs_policy"]

    placement_strategy {
        type  = "binpack"
        field = "cpu"
    }

    placement_constraints {
        type       = "memberOf"
        expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
    }
}
