variable "git_hash" {}

variable "cluster_name" {
  default = "blog"
}

variable "ami" {
  default = {
    "ecs" = "ami-62745007"
  }
}

variable "user" {
  default = "austburn"
}

variable "key_name" {
  default = "austburn_key"
}

variable "region" {
  default = "us-east-2"
}

variable "secret_bucket" {
  default = "austburn.secrets"
}

variable "azs" {
  default = ["us-east-2a", "us-east-2b"]
}

variable "private_cidrs" {
  default = {
    "us-east-2a" = "10.0.8.0/24"
    "us-east-2b" = "10.0.10.0/24"
  }
}

data "template_file" "ecs_cloud_config" {
  template       = "${file("${path.module}/templates/cloud_config.yml")}"

  vars {
    user         = "${var.user}"
    cluster_name = "${var.cluster_name}"
  }
}

data "template_file" "web_task_definition" {
  template      = "${file("${path.module}/templates/web-task-def.json")}"

  vars {
    repository  = "${aws_ecr_repository.austburn.repository_url}"
    git_hash    = "${var.git_hash}"
  }
}
