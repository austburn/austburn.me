resource "aws_db_subnet_group" "blog" {
  name       = "blog"
  subnet_ids = ["${aws_subnet.private_subnet.*.id}"]
}

resource "aws_db_instance" "blog" {
  allocated_storage       = 5
  storage_type            = "standard"
  engine                  = "postgres"
  engine_version          = "9.6.1"
  instance_class          = "db.t2.micro"
  name                    = "blog"
  username                = "${var.db_user}"
  password                = "${var.db_password}"
  db_subnet_group_name    = "blog"
  vpc_security_group_ids  = ["${aws_security_group.db.id}"]
}
