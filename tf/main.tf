terraform {
  backend "s3" {
    bucket  = "austburn.me"
    region = "us-east-2"
  }
}

provider "aws" {
    region = "${var.region}"
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

resource "aws_key_pair" "austburn" {
  key_name    = "${var.key_name}"
  public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFfa2h6vgQG12KSHbBHuApCelFzXq+i9WdhooDJudxRdg1Nov7wYCACf5NgY1EHV78sKSq5FpqvAfc2BTdL4rh31fXlvWOYSg7dPuTGHXISuo1yR8cVVJ5oQnK6/PDBO/ASpgj2Yg/ffkV7IL7MZddDgeQxViadfQ/QVUFybrL0HLTE1PZ2HoQaTWjKdgOpmRxEU7UbGqS198lr9Z3x9AaEej0E4fjE0WuoeF+pq/kHDfymE25XJounX9ECU03CENkI9a3nkLjx8MPKS7WMwxeaSdWBBMcjE7f0fcBM8NQ1smk5VxtAWN48yS861NwV8SmXq7Fr4exwj7ZBEvODlDvw9oPCLkJkPjbGDXJVkOgeOWNNVP/+mygOJqnXV8rZ5QVOG4/ExzMsiwUpvgxw2rKquOcoIxY8/GfLIg3AR+GDbHRLwMYEnulysCgIwe+4vgee1eDqldl7EOCGMvUrIP5T8aFUT7/6Pa1Q3ySfbmglKa03aXBfc4VCdhU59V8w+yv1Wam+arQ8B6Nsq6u8RP+TDUMcZi2YJiCI8uiVjcz05F6t77CXMQmaWo6/2sUMxGYb6me8xWCXds+Tgn0IwF+p5LEpL6cK1+KByEAdv660Rgor3DyGGBBRHkBUVTOvJzgqEau4od1WvbRjVqss8AhW84ciTCxAKSTTo7wc79QKw== austburn@gmail.com"
}

resource "aws_instance" "ecs_instance" {
  ami                         = "${var.ecs_ami}"
  instance_type               = "t2.micro"
  iam_instance_profile        = "${aws_iam_instance_profile.ecs.name}"
  user_data                   = "${data.template_file.cloud_config.rendered}"
  count                       = "${length(var.azs)}"
  availability_zone           = "${element(var.azs, count.index)}"
  subnet_id                   = "${element(aws_subnet.subnet.*.id, count.index)}"
  key_name                    = "${var.key_name}"
  associate_public_ip_address = true
  vpc_security_group_ids      = ["${aws_security_group.ecs.id}"]
  tags {
    Name = "ecs"
  }
}


# resource "aws_ecs_cluster" "cluster" {
#     name = "${var.cluster_name}"
# }

# resource "aws_ecs_service" "web" {
#     name          = "web-service"
#     cluster       = "${aws_ecs_cluster.cluster.id}"
#     desired_count = 2
#     iam_role      = "${aws_iam_role.ecsInstanceRole.arn}"
#     depends_on    = ["aws_iam_role_policy.ecs_policy"]

#     placement_strategy {
#         type  = "binpack"
#         field = "cpu"
#     }

#     placement_constraints {
#         type       = "memberOf"
#         expression = "attribute:ecs.availability-zone in [us-east-2a, us-east-2b]"
#     }
# }
