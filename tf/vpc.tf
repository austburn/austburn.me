resource "aws_vpc" "blog" {
  cidr_block    = "10.0.0.0/16"
}

resource "aws_subnet" "subnet" {
  vpc_id            = "${aws_vpc.blog.id}"
  count             = "${length(var.azs)}"
  cidr_block        = "${lookup(var.az_cidrs, element(var.azs, count.index))}"
  availability_zone = "${element(var.azs, count.index)}"
}

resource "aws_internet_gateway" "gw" {
  vpc_id   = "${aws_vpc.blog.id}"
}

resource "aws_eip" "nat_eip" {
  vpc      = true
  count    = "${length(var.azs)}"
}

resource "aws_nat_gateway" "gw" {
  allocation_id = "${element(aws_eip.nat_eip.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.subnet.*.id, count.index)}"
  count         = "${length(var.azs)}"
  depends_on    = ["aws_internet_gateway.gw"]
}
