resource "aws_vpc" "blog" {
  cidr_block    = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id   = "${aws_vpc.blog.id}"
}

resource "aws_route_table" "main" {
  vpc_id = "${aws_vpc.blog.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
}

resource "aws_route_table_association" "public_rt" {
  count          = "${length(var.azs)}"
  subnet_id       = "${element(aws_subnet.public_subnet.*.id, count.index)}"
  route_table_id  = "${aws_route_table.main.id}"
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = "${aws_vpc.blog.id}"
  count             = "${length(var.azs)}"
  cidr_block        = "${lookup(var.private_cidrs, element(var.azs, count.index))}"
  availability_zone = "${element(var.azs, count.index)}"
}

resource "aws_security_group" "ecs" {
  name    = "ecs"
  vpc_id  = "${aws_vpc.blog.id}"

  ingress {
    from_port       = 5050
    to_port         = 5050
    protocol        = "tcp"
    security_groups = ["${aws_security_group.alb.id}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb" {
  name    = "alb"
  vpc_id  = "${aws_vpc.blog.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
