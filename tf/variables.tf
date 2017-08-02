variable "docker_user" {}
variable "docker_password" {}
variable "docker_email" {}

variable "cluster_name" {
  default = "blog"
}
variable "registry" {
  default = "https://registry.austburn.me"
}

variable "ami" {
  default = {
    "ecs" = "ami-62745007"
    "bastion" = "ami-4191b524"
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

variable "public_cidrs" {
  default = {
    "us-east-2a" = "10.0.7.0/24"
    "us-east-2b" = "10.0.9.0/24"
  }
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

data "template_file" "ecs_agent_config" {
  template = "${file("${path.module}/templates/ecs.config")}"

  vars {
    cluster_name    = "${var.cluster_name}"
    registry        = "${var.registry}"
    docker_user     = "${var.docker_user}"
    docker_password = "${var.docker_password}"
    docker_email    = "${var.docker_email}"
  }
}
