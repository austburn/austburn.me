variable "db_user"          {}
variable "db_password"      {}

variable "ecs_ami" {
  default = "ami-62745007"
}

variable "user" {
  default = "austburn"
}

variable "key_name" {
  default = "austburn_key"
}

variable "cluster_name" {
  default = "blog"
}

variable "region" {
  default = "us-east-2"
}

variable "azs" {
  default = ["us-east-2a", "us-east-2b"]
}

variable "az_cidrs" {
  default = {
    "us-east-2a" = "10.0.1.0/24"
    "us-east-2b" = "10.0.2.0/24"
  }
}

data "template_file" "cloud_config" {
  template = "${file("${path.module}/cloud_config.yml")}"

  vars {
    user            = "${var.user}"
    cluster_name    = "${var.cluster_name}"
  }
}
