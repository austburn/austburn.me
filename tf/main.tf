terraform {
  backend "s3" {
    bucket  = "austburn.me"
    region = "us-east-2"
  }
}

provider "aws" {
    region = "${var.region}"
}

resource "aws_s3_bucket" "secrets" {
  bucket = "${var.secret_bucket}"
  acl    = "private"
  region = "${var.region}"
  policy = "${data.aws_iam_policy_document.s3_encryption_policy.json}"

  versioning {
    enabled = true
  }
}

resource "aws_key_pair" "austburn" {
  key_name    = "${var.key_name}"
  public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFfa2h6vgQG12KSHbBHuApCelFzXq+i9WdhooDJudxRdg1Nov7wYCACf5NgY1EHV78sKSq5FpqvAfc2BTdL4rh31fXlvWOYSg7dPuTGHXISuo1yR8cVVJ5oQnK6/PDBO/ASpgj2Yg/ffkV7IL7MZddDgeQxViadfQ/QVUFybrL0HLTE1PZ2HoQaTWjKdgOpmRxEU7UbGqS198lr9Z3x9AaEej0E4fjE0WuoeF+pq/kHDfymE25XJounX9ECU03CENkI9a3nkLjx8MPKS7WMwxeaSdWBBMcjE7f0fcBM8NQ1smk5VxtAWN48yS861NwV8SmXq7Fr4exwj7ZBEvODlDvw9oPCLkJkPjbGDXJVkOgeOWNNVP/+mygOJqnXV8rZ5QVOG4/ExzMsiwUpvgxw2rKquOcoIxY8/GfLIg3AR+GDbHRLwMYEnulysCgIwe+4vgee1eDqldl7EOCGMvUrIP5T8aFUT7/6Pa1Q3ySfbmglKa03aXBfc4VCdhU59V8w+yv1Wam+arQ8B6Nsq6u8RP+TDUMcZi2YJiCI8uiVjcz05F6t77CXMQmaWo6/2sUMxGYb6me8xWCXds+Tgn0IwF+p5LEpL6cK1+KByEAdv660Rgor3DyGGBBRHkBUVTOvJzgqEau4od1WvbRjVqss8AhW84ciTCxAKSTTo7wc79QKw== austburn@gmail.com"
}

resource "aws_instance" "bastion" {
  ami                         = "${var.ami["bastion"]}"
  instance_type               = "t2.nano"
  iam_instance_profile        = "${aws_iam_instance_profile.bastion.name}"
  user_data                   = "${data.template_file.bastion_cloud_config.rendered}"
  subnet_id                   = "${aws_subnet.public_subnet.id}"
  associate_public_ip_address = true
  key_name                    = "${var.key_name}"
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}"]
  depends_on                  = ["aws_iam_instance_profile.bastion"]
}

resource "aws_instance" "ecs_instance" {
  ami                         = "${var.ami["ecs"]}"
  instance_type               = "t2.micro"
  iam_instance_profile        = "${aws_iam_instance_profile.ecs.name}"
  user_data                   = "${data.template_file.ecs_cloud_config.rendered}"
  count                       = "${length(var.azs)}"
  availability_zone           = "${element(var.azs, count.index)}"
  subnet_id                   = "${element(aws_subnet.private_subnet.*.id, count.index)}"
  key_name                    = "${var.key_name}"
  vpc_security_group_ids      = ["${aws_security_group.ecs.id}"]
  tags {
    Name = "ecs"
  }
}

resource "aws_alb" "web" {
  name            = "web-alb"
  internal        = false
  security_groups = ["${aws_security_group.alb.id}"]
  subnets         = ["${aws_subnet.private_subnet.*.id}"]

  enable_deletion_protection = true
}

resource "aws_alb_target_group" "ecs" {
  name     = "alb-ecs-target"
  port     = 5050
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.blog.id}"
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = "${aws_alb.web.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.ecs.arn}"
    type             = "forward"
  }
}

resource "aws_ecs_cluster" "cluster" {
    name = "${var.cluster_name}"
}

resource "aws_ecs_service" "web" {
  name            = "web-service"
  cluster         = "${aws_ecs_cluster.cluster.id}"
  task_definition = "${aws_ecs_task_definition.web.arn}"
  desired_count   = 2
  iam_role        = "${aws_iam_role.ecs_service.name}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.ecs.id}"
    container_name   = "web"
    container_port   = "5050"
  }

  placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [${join(",", var.azs)}]"
  }

  depends_on = [
    "aws_iam_role_policy.ecs_service_policy",
    "aws_alb_listener.http"
  ]
}

resource "aws_ecs_task_definition" "web" {
  family                = "service"
  container_definitions = "${file("${path.module}/task-definitions/web.json")}"

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [${join(",", var.azs)}]"
  }
}
